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
        Description__c = 'Test Property Description ' + i
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
}
