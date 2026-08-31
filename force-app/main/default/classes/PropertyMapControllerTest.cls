@IsTest
private class PropertyMapControllerTest {
  private static Property__c createProperty(
    String name,
    Decimal latitude,
    Decimal longitude
  ) {
    return new Property__c(
      Name = name,
      Address__c = '100 Main Street',
      City__c = 'Mumbai',
      State__c = 'Maharashtra',
      Postal_Code__c = '400001',
      Country__c = 'India',
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 25000,
      Description__c = 'Property map controller test data',
      Location__Latitude__s = latitude,
      Location__Longitude__s = longitude
    );
  }

  @IsTest
  static void testGetPropertyLocationReturnsCoordinatesAndName() {
    Property__c propertyRecord = createProperty(
      'Mumbai Central Apartment',
      19.0760,
      72.8777
    );
    insert propertyRecord;

    Test.startTest();
    PropertyMapController.LocationData result =
      PropertyMapController.getPropertyLocation(propertyRecord.Id);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(19.0760, result.latitude);
    System.assertEquals(72.8777, result.longitude);
    System.assertEquals('Mumbai Central Apartment', result.propertyName);
  }

  @IsTest
  static void testGetPropertyLocationAllowsMissingCoordinates() {
    Property__c propertyRecord = createProperty(
      'Ungeocoded Apartment',
      null,
      null
    );
    insert propertyRecord;

    Test.startTest();
    PropertyMapController.LocationData result =
      PropertyMapController.getPropertyLocation(propertyRecord.Id);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(null, result.latitude);
    System.assertEquals(null, result.longitude);
    System.assertEquals('Ungeocoded Apartment', result.propertyName);
  }

  @IsTest
  static void testMultiplePropertyLookupsRemainIndependent() {
    List<Property__c> properties = new List<Property__c>{
      createProperty('Pune Villa', 18.5204, 73.8567),
      createProperty('Delhi Flat', 28.6139, 77.2090),
      createProperty('Kolkata House', 22.5726, 88.3639)
    };
    insert properties;

    Test.startTest();
    List<PropertyMapController.LocationData> results =
      new List<PropertyMapController.LocationData>();
    for (Property__c propertyRecord : properties) {
      results.add(
        PropertyMapController.getPropertyLocation(propertyRecord.Id)
      );
    }
    Test.stopTest();

    System.assertEquals(3, results.size());
    System.assertEquals(18.5204, results[0].latitude);
    System.assertEquals(73.8567, results[0].longitude);
    System.assertEquals('Pune Villa', results[0].propertyName);
    System.assertEquals(28.6139, results[1].latitude);
    System.assertEquals(77.2090, results[1].longitude);
    System.assertEquals('Delhi Flat', results[1].propertyName);
    System.assertEquals(22.5726, results[2].latitude);
    System.assertEquals(88.3639, results[2].longitude);
    System.assertEquals('Kolkata House', results[2].propertyName);
  }

  @IsTest
  static void testNullPropertyIdRaisesQueryException() {
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      PropertyMapController.getPropertyLocation(null);
    } catch (QueryException exceptionThrownByQuery) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'A null property ID should surface the query exception.'
    );
  }

  @IsTest
  static void testUnknownPropertyIdRaisesQueryException() {
    Id unknownPropertyId = 'a00000000000001AAA';
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      PropertyMapController.getPropertyLocation(unknownPropertyId);
    } catch (QueryException exceptionThrownByQuery) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'A valid-format but nonexistent property ID should fail predictably.'
    );
  }

  @IsTest
  static void testWrongObjectIdRaisesQueryException() {
    Account accountRecord = new Account(Name = 'Invalid Property Reference');
    insert accountRecord;
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      PropertyMapController.getPropertyLocation(accountRecord.Id);
    } catch (QueryException exceptionThrownByQuery) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'An ID for another object must not return a property location.'
    );
  }
}
