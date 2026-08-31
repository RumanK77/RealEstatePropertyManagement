public with sharing class MaintenanceRequestTriggerHandler {
  public static void assignLeastLoadedVendor(
    List<Maintenance_Request__c> newRequests
  ) {
    // Get all vendors
    List<Vendor__c> vendors = [
      SELECT Id, Name
      FROM Vendor__c
      ORDER BY Name
    ];

    if (vendors.isEmpty()) {
      return;
    }

    // Initialize workload for every vendor
    Map<Id, Integer> vendorWorkload = new Map<Id, Integer>();

    for (Vendor__c vendor : vendors) {
      vendorWorkload.put(vendor.Id, 0);
    }

    // Count active maintenance requests per vendor
    for (AggregateResult result : [
      SELECT Vendor__c vendorId, COUNT(Id) requestCount
      FROM Maintenance_Request__c
      WHERE Vendor__c != NULL AND Status__c IN ('Open', 'In Progress')
      GROUP BY Vendor__c
    ]) {
      Id vendorId = (Id) result.get('vendorId');
      Integer requestCount = (Integer) result.get('requestCount');

      if (vendorWorkload.containsKey(vendorId)) {
        vendorWorkload.put(vendorId, requestCount);
      }
    }

    // Assign each new request to the least-loaded vendor
    for (Maintenance_Request__c request : newRequests) {
      // Don't overwrite manually selected vendor
      if (request.Vendor__c != null) {
        continue;
      }

      Id leastLoadedVendorId;
      Integer lowestWorkload;

      for (Id vendorId : vendorWorkload.keySet()) {
        Integer workload = vendorWorkload.get(vendorId);

        if (lowestWorkload == null || workload < lowestWorkload) {
          lowestWorkload = workload;
          leastLoadedVendorId = vendorId;
        }
      }

      request.Vendor__c = leastLoadedVendorId;

      // Increase workload so bulk-created requests
      // are distributed among vendors
      vendorWorkload.put(
        leastLoadedVendorId,
        vendorWorkload.get(leastLoadedVendorId) + 1
      );
    }
  }
}
