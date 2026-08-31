@IsTest
private class PropertyTriggerHandlerTest {
  private static Property__c createProperty(String name, Id tenantId) {
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
      Description__c = 'Well-maintained rental property',
      Tenant__c = tenantId
    );
  }

  private static Tenant__c createTenant(String name, String email) {
    return new Tenant__c(
      Name = name,
      Email__c = email,
      Phone_Number__c = '9000000001'
    );
  }

  @IsTest
  static void testInsertWithTenantCreatesLeaseTask() {
    Tenant__c tenant = createTenant('Aarav Sharma', 'aarav@example.com');
    insert tenant;
    Property__c propertyRecord = createProperty('Mumbai Apartment', tenant.Id);

    Test.startTest();
    insert propertyRecord;
    Test.stopTest();

    List<Task> tasks = [
      SELECT Subject, WhatId, ActivityDate, Status, Priority, Description
      FROM Task
      WHERE WhatId = :propertyRecord.Id
    ];
    System.assertEquals(1, tasks.size());
    System.assertEquals('Generate Lease Agreement', tasks[0].Subject);
    System.assertEquals(Date.today().addDays(1), tasks[0].ActivityDate);
    System.assertEquals('Not Started', tasks[0].Status);
    System.assertEquals('Normal', tasks[0].Priority);
    System.assertEquals(
      'Generate a lease agreement for the assigned tenant.',
      tasks[0].Description
    );
  }

  @IsTest
  static void testInsertWithoutTenantCreatesNoTask() {
    Property__c propertyRecord = createProperty('Available Apartment', null);

    Test.startTest();
    insert propertyRecord;
    Test.stopTest();

    System.assertEquals(
      0,
      [SELECT COUNT() FROM Task WHERE WhatId = :propertyRecord.Id],
      'An unassigned property should not create a lease task.'
    );
  }

  @IsTest
  static void testTenantAssignmentOnUpdateCreatesTask() {
    Tenant__c tenant = createTenant('Isha Patel', 'isha@example.com');
    insert tenant;
    Property__c propertyRecord = createProperty('Pune Villa', null);
    insert propertyRecord;

    propertyRecord.Tenant__c = tenant.Id;
    Test.startTest();
    update propertyRecord;
    Test.stopTest();

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Task WHERE WhatId = :propertyRecord.Id],
      'Assigning a tenant should create one lease task.'
    );
  }

  @IsTest
  static void testUnchangedOrRemovedTenantCreatesNoTask() {
    Tenant__c tenant = createTenant('Neha Rao', 'neha@example.com');
    insert tenant;
    Property__c assignedProperty = createProperty('Assigned Flat', tenant.Id);
    Property__c unassignedProperty = createProperty('Unassigned Flat', null);
    insert new List<Property__c>{ assignedProperty, unassignedProperty };

    Integer initialTaskCount = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId IN :new List<Id>{ assignedProperty.Id, unassignedProperty.Id }
    ];
    System.assertEquals(1, initialTaskCount);

    assignedProperty.Name = 'Assigned Flat Updated';
    unassignedProperty.Name = 'Still Unassigned Flat';
    Test.startTest();
    update new List<Property__c>{ assignedProperty, unassignedProperty };
    Test.stopTest();

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Task
        WHERE WhatId IN :new List<Id>{ assignedProperty.Id, unassignedProperty.Id }
      ],
      'A tenant unchanged or removed must not create another task.'
    );
  }

  @IsTest
  static void testChangingTenantCreatesAnotherTask() {
    Tenant__c firstTenant = createTenant('Rohan Mehta', 'rohan@example.com');
    Tenant__c secondTenant = createTenant('Mira Shah', 'mira@example.com');
    insert new List<Tenant__c>{ firstTenant, secondTenant };
    Property__c propertyRecord = createProperty('Delhi Residence', firstTenant.Id);
    insert propertyRecord;

    propertyRecord.Tenant__c = secondTenant.Id;
    Test.startTest();
    update propertyRecord;
    Test.stopTest();

    System.assertEquals(
      2,
      [SELECT COUNT() FROM Task WHERE WhatId = :propertyRecord.Id],
      'Changing the assigned tenant should create a new lease task.'
    );
  }

  @IsTest
  static void testBulkInsertCreatesTasksOnlyForAssignedTenants() {
    List<Tenant__c> tenants = new List<Tenant__c>{
      createTenant('Tenant One', 'one@example.com'),
      createTenant('Tenant Two', 'two@example.com'),
      createTenant('Tenant Three', 'three@example.com')
    };
    insert tenants;

    List<Property__c> properties = new List<Property__c>{
      createProperty('Bulk Property 1', tenants[0].Id),
      createProperty('Bulk Property 2', null),
      createProperty('Bulk Property 3', tenants[1].Id),
      createProperty('Bulk Property 4', null),
      createProperty('Bulk Property 5', tenants[2].Id)
    };

    Test.startTest();
    insert properties;
    Test.stopTest();

    Set<Id> propertyIds = new Map<Id, Property__c>(properties).keySet();
    List<Task> tasks = [
      SELECT WhatId
      FROM Task
      WHERE WhatId IN :propertyIds
    ];
    System.assertEquals(3, tasks.size());
    Set<Id> taskPropertyIds = new Set<Id>();
    for (Task taskRecord : tasks) {
      taskPropertyIds.add(taskRecord.WhatId);
    }
    System.assertEquals(3, taskPropertyIds.size());
  }

  @IsTest
  static void testDirectHandlerWithEmptyListCreatesNoTasks() {
    Test.startTest();
    PropertyTriggerHandler.handleAfterInsertUpdate(
      new List<Property__c>(),
      null
    );
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM Task]);
  }

  @IsTest
  static void testMissingOldPropertyMapEntryRaisesException() {
    Tenant__c tenant = createTenant('Kabir Singh', 'kabir@example.com');
    insert tenant;
    Property__c propertyRecord = createProperty('Invalid Old Map Property', tenant.Id);
    insert propertyRecord;

    Boolean exceptionThrown = false;
    Test.startTest();
    try {
      PropertyTriggerHandler.handleAfterInsertUpdate(
        new List<Property__c>{ propertyRecord },
        new Map<Id, Property__c>()
      );
    } catch (NullPointerException exceptionThrownByHandler) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'An update without its old record should surface the handler error.'
    );
  }
}
