public with sharing class PropertyController {
  @AuraEnabled(cacheable=true)
  public static PropertyPageResult getProperties(
    Integer pageNumber,
    Integer pageSize,
    Decimal minPrice,
    Decimal maxPrice,
    String availabilityStatus,
    String furnishingStatus,
    Decimal userLatitude,
    Decimal userLongitude,
    Decimal distanceKm
  ) {
    // Default page number
    if (pageNumber == null || pageNumber < 1) {
      pageNumber = 1;
    }

    // Requirement: exactly 25 records per page
    pageSize = 25;

    Integer offsetSize = (pageNumber - 1) * pageSize;

    List<String> conditions = new List<String>();

    // Price filters
    if (minPrice != null) {
      conditions.add('Rent__c >= :minPrice');
    }

    if (maxPrice != null) {
      conditions.add('Rent__c <= :maxPrice');
    }

    // Availability filter
    if (String.isNotBlank(availabilityStatus)) {
      conditions.add('Status__c = :availabilityStatus');
    }

    // Furnishing filter
    if (String.isNotBlank(furnishingStatus)) {
      conditions.add('Furnishing_Status__c = :furnishingStatus');
    }

    // Nearby distance filter
    if (
      userLatitude != null &&
      userLongitude != null &&
      distanceKm != null &&
      distanceKm > 0
    ) {
      conditions.add(
        'DISTANCE(' +
          'Location__c, ' +
          'GEOLOCATION(:userLatitude, :userLongitude), ' +
          '\'km\'' +
          ') < :distanceKm'
      );
    }

    String whereClause = '';

    if (!conditions.isEmpty()) {
      whereClause = ' WHERE ' + String.join(conditions, ' AND ');
    }

    // Total records
    String countQuery = 'SELECT COUNT() FROM Property__c' + whereClause;

    Integer totalRecords = Database.countQuery(countQuery);

    // Property records
    String query =
      'SELECT Id, Name, Address__c, City__c, State__c, ' +
      'Country__c, Postal_Code__c, Type__c, ' +
      'Furnishing_Status__c, Status__c, Rent__c, ' +
      'Description__c, Location__c ' +
      'FROM Property__c' +
      whereClause +
      ' ORDER BY CreatedDate DESC' +
      ' LIMIT :pageSize OFFSET :offsetSize';

    List<Property__c> properties = Database.query(query);

    return new PropertyPageResult(
      properties,
      totalRecords,
      pageNumber,
      pageSize
    );
  }

  public class PropertyPageResult {
    @AuraEnabled
    public List<Property__c> properties { get; set; }

    @AuraEnabled
    public Integer totalRecords { get; set; }

    @AuraEnabled
    public Integer pageNumber { get; set; }

    @AuraEnabled
    public Integer pageSize { get; set; }

    public PropertyPageResult(
      List<Property__c> properties,
      Integer totalRecords,
      Integer pageNumber,
      Integer pageSize
    ) {
      this.properties = properties;
      this.totalRecords = totalRecords;
      this.pageNumber = pageNumber;
      this.pageSize = pageSize;
    }
  }
}
