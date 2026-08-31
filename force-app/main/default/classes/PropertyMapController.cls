public with sharing class PropertyMapController {
  public class LocationData {
    @AuraEnabled
    public Decimal latitude { get; set; }

    @AuraEnabled
    public Decimal longitude { get; set; }

    @AuraEnabled
    public String propertyName { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static LocationData getPropertyLocation(Id propertyId) {
    Property__c propertyRecord = [
      SELECT Id, Name, Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyId
      LIMIT 1
    ];

    LocationData result = new LocationData();

    result.latitude = propertyRecord.Location__Latitude__s;
    result.longitude = propertyRecord.Location__Longitude__s;
    result.propertyName = propertyRecord.Name;

    return result;
  }
}
