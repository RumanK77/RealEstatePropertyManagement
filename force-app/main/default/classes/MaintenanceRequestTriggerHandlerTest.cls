@IsTest
private class MaintenanceRequestTriggerHandlerTest {
  @IsTest
  static void testAssignLeastLoadedVendor() {
    // Create Vendors
    Vendor__c vendor1 = new Vendor__c(Name = 'Vendor 1');

    Vendor__c vendor2 = new Vendor__c(Name = 'Vendor 2');

    insert new List<Vendor__c>{ vendor1, vendor2 };

    // Create existing requests for Vendor 1
    Property__c propertyRecord = new Property__c(
      Name = 'Test Property',
      Address__c = 'Test Address',
      City__c = 'Mumbai',
      State__c = 'Maharashtra',
      Postal_Code__c = '400001',
      Country__c = 'India',
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 10000,
      Description__c = 'Test Description'
    );

    insert propertyRecord;

    // Vendor 1 already has 2 active requests
    List<Maintenance_Request__c> existingRequests = new List<Maintenance_Request__c>();

    for (Integer i = 0; i < 2; i++) {
      existingRequests.add(
        new Maintenance_Request__c(
          Property__c = propertyRecord.Id,
          Vendor__c = vendor1.Id,
          Status__c = 'Open',
          Description__c = 'Existing Request ' + i
        )
      );
    }

    insert existingRequests;

    Test.startTest();

    // Create a new request without selecting a vendor
    Maintenance_Request__c newRequest = new Maintenance_Request__c(
      Property__c = propertyRecord.Id,
      Status__c = 'Open',
      Description__c = 'New Maintenance Request'
    );

    insert newRequest;

    Test.stopTest();

    // Verify Vendor 2 was assigned because it has less workload
    Maintenance_Request__c result = [
      SELECT Id, Vendor__c
      FROM Maintenance_Request__c
      WHERE Id = :newRequest.Id
    ];

    System.assertEquals(
      vendor2.Id,
      result.Vendor__c,
      'The least loaded vendor should be assigned.'
    );
  }

  @IsTest
  static void testBulkAssignment() {
    Vendor__c vendor1 = new Vendor__c(Name = 'Vendor A');
    Vendor__c vendor2 = new Vendor__c(Name = 'Vendor B');

    insert new List<Vendor__c>{ vendor1, vendor2 };

    Property__c propertyRecord = new Property__c(
      Name = 'Bulk Test Property',
      Address__c = 'Test Address',
      City__c = 'Pune',
      State__c = 'Maharashtra',
      Postal_Code__c = '411001',
      Country__c = 'India',
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 15000,
      Description__c = 'Bulk Test Description'
    );

    insert propertyRecord;

    List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();

    // Create multiple requests at once
    for (Integer i = 0; i < 10; i++) {
      requests.add(
        new Maintenance_Request__c(
          Property__c = propertyRecord.Id,
          Status__c = 'Open',
          Description__c = 'Bulk Request ' + i
        )
      );
    }

    Test.startTest();

    insert requests;

    Test.stopTest();

    // Verify all requests received a vendor
    List<Maintenance_Request__c> results = [
      SELECT Id, Vendor__c
      FROM Maintenance_Request__c
      WHERE Id IN :requests
    ];

    System.assertEquals(10, results.size());

    for (Maintenance_Request__c request : results) {
      System.assertNotEquals(
        null,
        request.Vendor__c,
        'Every request should have a vendor assigned.'
      );
    }
  }
}
