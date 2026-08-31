public with sharing class PropertyGeocodingService implements Queueable, Database.AllowsCallouts {
  private Id propertyId;

  public PropertyGeocodingService(Id propertyId) {
    this.propertyId = propertyId;
  }

  public void execute(QueueableContext context) {
    Property__c propertyRecord = [
      SELECT Id, Address__c, City__c, State__c, Postal_Code__c, Country__c
      FROM Property__c
      WHERE Id = :propertyId
      LIMIT 1
    ];

    String address = buildAddress(propertyRecord);

    if (String.isBlank(address)) {
      return;
    }

    try {
      String encodedAddress = EncodingUtil.urlEncode(address, 'UTF-8');

      HttpRequest request = new HttpRequest();

      request.setEndpoint(
        'https://nominatim.openstreetmap.org/search?q=' +
          encodedAddress +
          '&format=json&limit=1'
      );

      request.setMethod('GET');

      request.setHeader(
        'User-Agent',
        'Salesforce Property Management Application'
      );

      Http http = new Http();
      HttpResponse response = http.send(request);

      if (response.getStatusCode() == 200) {
        List<Object> results = (List<Object>) JSON.deserializeUntyped(
          response.getBody()
        );

        if (!results.isEmpty()) {
          Map<String, Object> locationData = (Map<String, Object>) results[0];

          Decimal latitude = Decimal.valueOf(
            String.valueOf(locationData.get('lat'))
          );

          Decimal longitude = Decimal.valueOf(
            String.valueOf(locationData.get('lon'))
          );

          Property__c propertyUpdate = new Property__c(
            Id = propertyId,
            Location__Latitude__s = latitude,
            Location__Longitude__s = longitude
          );

          update propertyUpdate;
        }
      }
    } catch (Exception e) {
      System.debug('Error geocoding property: ' + e.getMessage());
    }
  }

  private static String buildAddress(Property__c propertyRecord) {
    List<String> addressParts = new List<String>();

    if (String.isNotBlank(propertyRecord.Address__c)) {
      addressParts.add(propertyRecord.Address__c);
    }

    if (String.isNotBlank(propertyRecord.City__c)) {
      addressParts.add(propertyRecord.City__c);
    }

    if (String.isNotBlank(propertyRecord.State__c)) {
      addressParts.add(propertyRecord.State__c);
    }

    if (String.isNotBlank(propertyRecord.Postal_Code__c)) {
      addressParts.add(propertyRecord.Postal_Code__c);
    }

    if (String.isNotBlank(propertyRecord.Country__c)) {
      addressParts.add(propertyRecord.Country__c);
    }

    return String.join(addressParts, ', ');
  }
}
