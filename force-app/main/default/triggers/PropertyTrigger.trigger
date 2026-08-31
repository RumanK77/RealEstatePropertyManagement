trigger PropertyTrigger on Property__c(after insert, after update) {
  PropertyTriggerHandler.handleAfterInsertUpdate(Trigger.new, Trigger.oldMap);
}
