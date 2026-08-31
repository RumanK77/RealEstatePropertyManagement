@IsTest
private class PropertyFormControllerTest {
  private class GeocodingMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest request) {
      System.assertEquals('GET', request.getMethod());
      System.assertEquals(
        'Salesforce Property Management Application',
        request.getHeader('User-Agent')
      );

      HttpResponse response = new HttpResponse();
      response.setStatusCode(200);
      response.setBody('[{"lat":"19.0760","lon":"72.8777"}]');
      return response;
    }
  }

  private static Property__c createProperty(String name) {
    return new Property__c(
      Name = name,
      Address__c = '100 Marine Drive',
      City__c = 'Mumbai',
      State__c = 'Maharashtra',
      Postal_Code__c = '400001',
      Country__c = 'India',
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 35000,
      Description__c = 'Modern apartment near the waterfront'
    );
  }

  private static PropertyFormController.FileData createFile(
    String fileName,
    String contents
  ) {
    PropertyFormController.FileData fileData =
      new PropertyFormController.FileData();
    fileData.fileName = fileName;
    fileData.base64Data = EncodingUtil.base64Encode(Blob.valueOf(contents));
    return fileData;
  }

  private static void assertAuraException(
    Property__c propertyRecord,
    List<PropertyFormController.FileData> files
  ) {
    Boolean exceptionThrown = false;
    try {
      PropertyFormController.createPropertyWithImages(propertyRecord, files);
    } catch (AuraHandledException exceptionThrownByController) {
      exceptionThrown = true;
    }
    System.assertEquals(true, exceptionThrown);
  }

  @IsTest
  static void testCreatePropertyWithOneImageAndRunsGeocodingJob() {
    Property__c propertyRecord = createProperty('Mumbai Waterfront Apartment');
    List<PropertyFormController.FileData> files = new List<PropertyFormController.FileData>{
      createFile('front.jpg', 'front image bytes')
    };
    Test.setMock(HttpCalloutMock.class, new GeocodingMock());

    Test.startTest();
    Id propertyId = PropertyFormController.createPropertyWithImages(
      propertyRecord,
      files
    );
    System.assertEquals(1, Limits.getQueueableJobs());
    Test.stopTest();

    System.assertNotEquals(null, propertyId);
    Property__c savedProperty = [
      SELECT Id, Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyId
    ];
    System.assertEquals(19.0760, savedProperty.Location__Latitude__s);
    System.assertEquals(72.8777, savedProperty.Location__Longitude__s);

    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :propertyId
    ];
    System.assertEquals(1, links.size());
    List<ContentVersion> versions = [
      SELECT Title, PathOnClient, ContentDocumentId
      FROM ContentVersion
      WHERE ContentDocumentId = :links[0].ContentDocumentId
    ];
    System.assertEquals(1, versions.size());
    System.assertEquals('front', versions[0].Title);
    System.assertEquals('front.jpg', versions[0].PathOnClient);
    System.assertNotEquals(null, versions[0].ContentDocumentId);
  }

  @IsTest
  static void testCreatePropertyWithMultipleImagesCreatesAllLinks() {
    Property__c propertyRecord = createProperty('Pune Family Villa');
    List<PropertyFormController.FileData> files = new List<PropertyFormController.FileData>{
      createFile('living-room.png', 'living room'),
      createFile('floorplan.pdf', 'floor plan'),
      createFile('README', 'image without extension')
    };
    Test.setMock(HttpCalloutMock.class, new GeocodingMock());

    Test.startTest();
    Id propertyId = PropertyFormController.createPropertyWithImages(
      propertyRecord,
      files
    );
    Test.stopTest();

    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :propertyId
    ];
    Set<Id> documentIds = new Set<Id>();
    for (ContentDocumentLink link : links) {
      documentIds.add(link.ContentDocumentId);
    }
    List<ContentVersion> versions = [
      SELECT Title, PathOnClient, ContentDocumentId
      FROM ContentVersion
      WHERE ContentDocumentId IN :documentIds
      ORDER BY Title
    ];
    System.assertEquals(3, versions.size());
    Map<String, ContentVersion> versionsByPath =
      new Map<String, ContentVersion>();
    for (ContentVersion version : versions) {
      versionsByPath.put(version.PathOnClient, version);
    }
    System.assertEquals('floorplan', versionsByPath.get('floorplan.pdf').Title);
    System.assertEquals(
      'living-room',
      versionsByPath.get('living-room.png').Title
    );
    System.assertEquals('README', versionsByPath.get('README').Title);
    System.assertEquals(3, links.size());
  }

  @IsTest
  static void testInvalidEntriesAreSkippedWhenValidImageExists() {
    Property__c propertyRecord = createProperty('Mixed Image Data Property');
    PropertyFormController.FileData blankName = createFile(
      'ignored.txt',
      'ignored'
    );
    blankName.fileName = ' ';
    PropertyFormController.FileData blankData = createFile(
      'ignored-two.txt',
      'ignored'
    );
    blankData.base64Data = ' ';

    List<PropertyFormController.FileData> files =
      new List<PropertyFormController.FileData>{
        null,
        blankName,
        blankData,
        createFile('valid.jpeg', 'valid image')
      };
    Test.setMock(HttpCalloutMock.class, new GeocodingMock());

    Test.startTest();
    Id propertyId = PropertyFormController.createPropertyWithImages(
      propertyRecord,
      files
    );
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM ContentVersion
        WHERE PathOnClient = 'valid.jpeg'
      ]
    );
  }

  @IsTest
  static void testNullPropertyRecordThrowsAuraHandledException() {
    assertAuraException(
      null,
      new List<PropertyFormController.FileData>{
        createFile('image.jpg', 'image')
      }
    );
  }

  @IsTest
  static void testNullOrEmptyFilesThrowsAuraHandledException() {
    assertAuraException(createProperty('Null Files Property'), null);
    assertAuraException(
      createProperty('Empty Files Property'),
      new List<PropertyFormController.FileData>()
    );
  }

  @IsTest
  static void testOnlyInvalidFileDataThrowsAuraHandledException() {
    PropertyFormController.FileData invalidName =
      new PropertyFormController.FileData();
    invalidName.fileName = '';
    invalidName.base64Data = EncodingUtil.base64Encode(Blob.valueOf('data'));

    PropertyFormController.FileData invalidData =
      new PropertyFormController.FileData();
    invalidData.fileName = 'image.jpg';
    invalidData.base64Data = '';

    assertAuraException(
      createProperty('Invalid Files Property'),
      new List<PropertyFormController.FileData>{ null, invalidName, invalidData }
    );
  }

  @IsTest
  static void testDmlFailureIsRolledBackAndWrapped() {
    Property__c invalidProperty = createProperty('Invalid Required Data Property');
    invalidProperty.Address__c = null;

    assertAuraException(
      invalidProperty,
      new List<PropertyFormController.FileData>{
        createFile('image.jpg', 'image')
      }
    );

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Property__c WHERE Name = 'Invalid Required Data Property']
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM ContentVersion WHERE PathOnClient = 'image.jpg']
    );
  }
}
