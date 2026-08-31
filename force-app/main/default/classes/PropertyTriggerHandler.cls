public class PropertyTriggerHandler {
  public static void handleAfterInsertUpdate(
    List<Property__c> newProperties,
    Map<Id, Property__c> oldPropertyMap
  ) {
    List<Task> tasksToCreate = new List<Task>();

    for (Property__c propertyRecord : newProperties) {
      Boolean tenantWasAssigned = false;

      // For newly inserted Property
      if (oldPropertyMap == null) {
        tenantWasAssigned = propertyRecord.Tenant__c != null;
      }
      // For updated Property
      else {
        Property__c oldProperty = oldPropertyMap.get(propertyRecord.Id);

        tenantWasAssigned =
          propertyRecord.Tenant__c != null &&
          propertyRecord.Tenant__c != oldProperty.Tenant__c;
      }

      if (tenantWasAssigned) {
        tasksToCreate.add(
          new Task(
            Subject = 'Generate Lease Agreement',
            WhatId = propertyRecord.Id,
            ActivityDate = Date.today().addDays(1),
            Status = 'Not Started',
            Priority = 'Normal',
            Description = 'Generate a lease agreement for the assigned tenant.'
          )
        );
      }
    }

    if (!tasksToCreate.isEmpty()) {
      insert tasksToCreate;
    }
  }
}
