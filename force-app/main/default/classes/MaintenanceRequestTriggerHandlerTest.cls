@IsTest
private class MaintenanceRequestTriggerHandlerTest {
  @testSetup
  static void setupData() {
    insert new List<Property__c>{
      createProperty('Test Property 1', 'Mumbai'),
      createProperty('Test Property 2', 'Pune')
    };
  }

  private static Property__c createProperty(String name, String city) {
    return new Property__c(
      Name = name,
      Address__c = '100 Main Street',
      City__c = city,
      State__c = 'Maharashtra',
      Postal_Code__c = '400001',
      Country__c = 'India',
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 25000,
      Description__c = 'Well-maintained rental property'
    );
  }

  private static List<Vendor__c> createVendors(Integer count) {
    List<Vendor__c> vendors = new List<Vendor__c>();
    for (Integer i = 1; i <= count; i++) {
      vendors.add(
        new Vendor__c(
          Name = 'Vendor ' + String.valueOf(i),
          Phone_Number__c = '900000000' + String.valueOf(i),
          Email__c = 'vendor' + String.valueOf(i) + '@example.com'
        )
      );
    }
    insert vendors;
    return vendors;
  }

  private static Maintenance_Request__c createRequest(
    Id propertyId,
    Id vendorId,
    String status,
    String description
  ) {
    return new Maintenance_Request__c(
      Property__c = propertyId,
      Vendor__c = vendorId,
      Status__c = status,
      Description__c = description
    );
  }

  private static Id getPropertyId() {
    return [SELECT Id FROM Property__c ORDER BY Name LIMIT 1].Id;
  }

  @IsTest
  static void testLeastLoadedVendorUsesOnlyActiveWorkload() {
    List<Vendor__c> vendors = createVendors(3);
    Id propertyId = getPropertyId();

    insert new List<Maintenance_Request__c>{
      createRequest(propertyId, vendors[0].Id, 'Open', 'Active request 1'),
      createRequest(propertyId, vendors[0].Id, 'In Progress', 'Active request 2'),
      createRequest(propertyId, vendors[1].Id, 'Open', 'Active request 3'),
      createRequest(propertyId, vendors[2].Id, 'Completed', 'Completed request'),
      createRequest(propertyId, vendors[2].Id, 'Cancelled', 'Cancelled request')
    };

    Maintenance_Request__c newRequest = createRequest(
      propertyId,
      null,
      'Open',
      'New plumbing request'
    );

    Test.startTest();
    insert newRequest;
    Test.stopTest();

    Maintenance_Request__c result = [
      SELECT Vendor__c
      FROM Maintenance_Request__c
      WHERE Id = :newRequest.Id
    ];
    System.assertEquals(
      vendors[2].Id,
      result.Vendor__c,
      'The vendor with no active requests should be selected.'
    );
  }

  @IsTest
  static void testManualVendorIsNotOverwritten() {
    List<Vendor__c> vendors = createVendors(2);
    Maintenance_Request__c request = createRequest(
      getPropertyId(),
      vendors[1].Id,
      'Open',
      'Tenant-selected vendor request'
    );

    Test.startTest();
    insert request;
    Test.stopTest();

    Maintenance_Request__c result = [
      SELECT Vendor__c
      FROM Maintenance_Request__c
      WHERE Id = :request.Id
    ];
    System.assertEquals(
      vendors[1].Id,
      result.Vendor__c,
      'A manually selected vendor must be preserved.'
    );
  }

  @IsTest
  static void testBulkRequestsAreDistributedAcrossVendors() {
    List<Vendor__c> vendors = createVendors(3);
    Id propertyId = getPropertyId();

    insert createRequest(
      propertyId,
      vendors[0].Id,
      'Open',
      'Existing active workload'
    );

    List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>();
    for (Integer i = 0; i < 9; i++) {
      requests.add(
        createRequest(propertyId, null, 'Open', 'Bulk request ' + String.valueOf(i))
      );
    }

    Test.startTest();
    insert requests;
    Test.stopTest();

    Map<Id, Integer> countsByVendor = new Map<Id, Integer>();
    for (AggregateResult aggregate : [
      SELECT Vendor__c vendorId, COUNT(Id) requestCount
      FROM Maintenance_Request__c
      WHERE Vendor__c IN :vendors
      GROUP BY Vendor__c
    ]) {
      countsByVendor.put(
        (Id) aggregate.get('vendorId'),
        (Integer) aggregate.get('requestCount')
      );
    }

    System.assertEquals(3, countsByVendor.size());
    Integer minimumWorkload = 1000;
    Integer maximumWorkload = 0;
    Integer totalWorkload = 0;
    for (Vendor__c vendor : vendors) {
      Integer workload = countsByVendor.get(vendor.Id);
      minimumWorkload = Math.min(minimumWorkload, workload);
      maximumWorkload = Math.max(maximumWorkload, workload);
      totalWorkload += workload;
    }
    System.assertEquals(10, totalWorkload);
    System.assert(
      maximumWorkload - minimumWorkload <= 1,
      'Bulk assignment should keep vendor workloads balanced.'
    );
    for (Maintenance_Request__c request : [
      SELECT Vendor__c
      FROM Maintenance_Request__c
      WHERE Id IN :requests
    ]) {
      System.assertNotEquals(null, request.Vendor__c);
    }
  }

  @IsTest
  static void testBulkInsertHandlesManualAndAutomaticRequests() {
    List<Vendor__c> vendors = createVendors(2);
    Id propertyId = getPropertyId();
    List<Maintenance_Request__c> requests = new List<Maintenance_Request__c>{
      createRequest(propertyId, vendors[0].Id, 'Open', 'Manual vendor request'),
      createRequest(propertyId, null, 'In Progress', 'Automatic request 1'),
      createRequest(propertyId, null, 'Open', 'Automatic request 2')
    };

    Test.startTest();
    insert requests;
    Test.stopTest();

    List<Maintenance_Request__c> results = [
      SELECT Vendor__c
      FROM Maintenance_Request__c
      WHERE Id IN :requests
      ORDER BY CreatedDate
    ];
    System.assertEquals(vendors[0].Id, results[0].Vendor__c);
    System.assertNotEquals(null, results[1].Vendor__c);
    System.assertNotEquals(null, results[2].Vendor__c);
  }

  @IsTest
  static void testNoVendorsLeavesRequestsUnassigned() {
    Maintenance_Request__c request = new Maintenance_Request__c(
      Property__c = getPropertyId(),
      Status__c = 'Open',
      Description__c = 'Request awaiting vendor availability'
    );

    Test.startTest();
    MaintenanceRequestTriggerHandler.assignLeastLoadedVendor(
      new List<Maintenance_Request__c>{ request }
    );
    Test.stopTest();

    System.assertEquals(
      null,
      request.Vendor__c,
      'Requests remain unassigned when no vendors exist.'
    );
  }
}
