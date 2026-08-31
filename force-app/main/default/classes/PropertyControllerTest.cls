@IsTest
private class PropertyControllerTest {
  @testSetup
  static void setupData() {
    List<Property__c> properties = new List<Property__c>();

    for (Integer i = 1; i <= 30; i++) {
      Property__c propertyRecord = new Property__c(
        Name = 'Test Property ' + i,
        Address__c = 'Address ' + i,
        City__c = 'Mumbai',
        State__c = 'Maharashtra',
        Postal_Code__c = '400001',
        Country__c = 'India',
        Type__c = i <= 15 ? 'Residential' : 'Commercial',
        Furnishing_Status__c = i <= 10
          ? 'Furnished'
          : i <= 20 ? 'Semi-Furnished' : 'Unfurnished',
        Status__c = i <= 20 ? 'Available' : 'Occupied',
        Rent__c = 1000 * i,
        Description__c = 'Test Property Description ' + i,
        Location__Latitude__s = i <= 10 ? 19.0760 : 19.2000,
        Location__Longitude__s = i <= 10 ? 72.8777 : 73.0000
      );

      properties.add(propertyRecord);
    }

    insert properties;
  }

  @IsTest
  static void testPagination() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      1,
      25,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(
      25,
      result.properties.size(),
      'First page should contain 25 records'
    );

    System.assertEquals(30, result.totalRecords, 'Total records should be 30');

    System.assertEquals(1, result.pageNumber);
    System.assertEquals(25, result.pageSize);
  }

  @IsTest
  static void testSecondPage() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      2,
      25,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(
      5,
      result.properties.size(),
      'Second page should contain remaining 5 records'
    );

    System.assertEquals(30, result.totalRecords);
  }

  @IsTest
  static void testPriceFilter() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      1,
      25,
      5000,
      10000,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    for (Property__c propertyRecord : result.properties) {
      System.assert(
        propertyRecord.Rent__c >= 5000 && propertyRecord.Rent__c <= 10000,
        'Property should be within the selected price range'
      );
    }
  }

  @IsTest
  static void testAvailabilityFilter() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      1,
      25,
      null,
      null,
      'Available',
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(20, result.totalRecords);

    for (Property__c propertyRecord : result.properties) {
      System.assertEquals('Available', propertyRecord.Status__c);
    }
  }

  @IsTest
  static void testFurnishingFilter() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      1,
      25,
      null,
      null,
      null,
      'Furnished',
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(10, result.totalRecords);

    for (Property__c propertyRecord : result.properties) {
      System.assertEquals('Furnished', propertyRecord.Furnishing_Status__c);
    }
  }

  @IsTest
  static void testDefaultValues() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(1, result.pageNumber);
    System.assertEquals(25, result.pageSize);
  }

  @IsTest
  static void testInvalidPageNumberDefaultsToFirstPage() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      0,
      1,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(1, result.pageNumber);
    System.assertEquals(25, result.properties.size());
  }

  @IsTest
  static void testDistanceFilter() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      1,
      25,
      null,
      null,
      null,
      null,
      19.0760,
      72.8777,
      5
    );

    Test.stopTest();

    System.assertEquals(10, result.totalRecords);
    System.assertEquals(10, result.properties.size());
    for (Property__c propertyRecord : result.properties) {
      System.assertEquals(19.0760, propertyRecord.Location__Latitude__s);
      System.assertEquals(72.8777, propertyRecord.Location__Longitude__s);
    }
  }

  @IsTest
  static void testAllFiltersTogether() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      1,
      100,
      5000,
      15000,
      'Available',
      'Furnished',
      19.0760,
      72.8777,
      5
    );

    Test.stopTest();

    System.assertEquals(6, result.totalRecords);
    System.assertEquals(6, result.properties.size());
    for (Property__c propertyRecord : result.properties) {
      System.assert(
        propertyRecord.Rent__c >= 5000 && propertyRecord.Rent__c <= 15000,
        'Every result should satisfy the price range'
      );
      System.assertEquals('Available', propertyRecord.Status__c);
      System.assertEquals('Furnished', propertyRecord.Furnishing_Status__c);
    }
  }

  @IsTest
  static void testPageBeyondAvailableRecordsReturnsEmptyList() {
    Test.startTest();

    PropertyController.PropertyPageResult result = PropertyController.getProperties(
      3,
      25,
      null,
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    System.assertEquals(30, result.totalRecords);
    System.assertEquals(3, result.pageNumber);
    System.assertEquals(0, result.properties.size());
  }
}
