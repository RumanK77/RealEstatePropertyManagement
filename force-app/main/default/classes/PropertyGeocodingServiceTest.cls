@IsTest
private class PropertyGeocodingServiceTest {
  private class GeocodingMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;
    private Boolean throwException;

    GeocodingMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
      this.throwException = false;
    }

    GeocodingMock(Boolean throwException) {
      this.statusCode = 200;
      this.body = '[]';
      this.throwException = throwException;
    }

    public HttpResponse respond(HttpRequest request) {
      System.assertEquals('GET', request.getMethod());
      System.assertEquals(
        'Salesforce Property Management Application',
        request.getHeader('User-Agent')
      );
      System.assert(
        request.getEndpoint().contains('nominatim.openstreetmap.org/search?q='),
        'The Nominatim endpoint should be used.'
      );
      System.assert(
        request.getEndpoint().contains('format=json&limit=1'),
        'The request should ask for one JSON result.'
      );

      if (throwException) {
        throw new CalloutException('Simulated geocoding service failure');
      }

      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCode);
      response.setBody(body);
      return response;
    }
  }

  private static Property__c createProperty(
    String name,
    String address,
    String city,
    String state,
    String postalCode,
    String country
  ) {
    return new Property__c(
      Name = name,
      Address__c = address,
      City__c = city,
      State__c = state,
      Postal_Code__c = postalCode,
      Country__c = country,
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 30000,
      Description__c = 'Test property for geocoding'
    );
  }

  @IsTest
  static void testQueueableSuccessUpdatesCoordinates() {
    Property__c propertyRecord = createProperty(
      'Geocoded Property',
      '221B Baker Street',
      'London',
      'England',
      'NW1 6XE',
      'United Kingdom'
    );
    insert propertyRecord;
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodingMock(200, '[{"lat":"51.523767","lon":"-0.158555"}]')
    );

    Test.startTest();
    Id jobId = System.enqueueJob(new PropertyGeocodingService(propertyRecord.Id));
    Test.stopTest();

    System.assertNotEquals(null, jobId);
    Property__c result = [
      SELECT Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyRecord.Id
    ];
    System.assertEquals(51.523767, result.Location__Latitude__s);
    System.assertEquals(-0.158555, result.Location__Longitude__s);
  }

  @IsTest
  static void testDirectExecutionWithPartialAddress() {
    Property__c propertyRecord = createProperty(
      'Partial Address Property',
      'Main Road',
      'Pune',
      'Maharashtra',
      '411001',
      'India'
    );
    insert propertyRecord;
    Test.setMock(
      HttpCalloutMock.class,
      new GeocodingMock(200, '[{"lat":"18.5204","lon":"73.8567"}]')
    );

    Test.startTest();
    new PropertyGeocodingService(propertyRecord.Id).execute(null);
    Test.stopTest();

    Property__c result = [
      SELECT Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyRecord.Id
    ];
    System.assertEquals(18.5204, result.Location__Latitude__s);
    System.assertEquals(73.8567, result.Location__Longitude__s);
  }

  @IsTest
  static void testSuccessfulResponseWithNoResultsDoesNotUpdate() {
    Property__c propertyRecord = createProperty(
      'Unmatched Property',
      'Unknown Road',
      'Unknown City',
      'Unknown State',
      '000000',
      'India'
    );
    insert propertyRecord;
    Test.setMock(HttpCalloutMock.class, new GeocodingMock(200, '[]'));

    Test.startTest();
    new PropertyGeocodingService(propertyRecord.Id).execute(null);
    Test.stopTest();

    Property__c result = [
      SELECT Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyRecord.Id
    ];
    System.assertEquals(null, result.Location__Latitude__s);
    System.assertEquals(null, result.Location__Longitude__s);
  }

  @IsTest
  static void testNon200ResponseIsIgnored() {
    Property__c propertyRecord = createProperty(
      'Unavailable Service Property',
      '10 Downing Street',
      'London',
      'England',
      'SW1A 2AA',
      'United Kingdom'
    );
    insert propertyRecord;
    Test.setMock(HttpCalloutMock.class, new GeocodingMock(503, 'Service unavailable'));

    Test.startTest();
    new PropertyGeocodingService(propertyRecord.Id).execute(null);
    Test.stopTest();

    Property__c result = [
      SELECT Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyRecord.Id
    ];
    System.assertEquals(null, result.Location__Latitude__s);
    System.assertEquals(null, result.Location__Longitude__s);
  }

  @IsTest
  static void testMalformedResponseIsHandled() {
    Property__c propertyRecord = createProperty(
      'Malformed Response Property',
      '1600 Pennsylvania Avenue',
      'Washington',
      'DC',
      '20500',
      'United States'
    );
    insert propertyRecord;
    Test.setMock(HttpCalloutMock.class, new GeocodingMock(200, '{"lat":"bad"}'));

    Test.startTest();
    new PropertyGeocodingService(propertyRecord.Id).execute(null);
    Test.stopTest();

    Property__c result = [
      SELECT Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyRecord.Id
    ];
    System.assertEquals(null, result.Location__Latitude__s);
    System.assertEquals(null, result.Location__Longitude__s);
  }

  @IsTest
  static void testCalloutExceptionIsHandled() {
    Property__c propertyRecord = createProperty(
      'Callout Failure Property',
      '1 Test Street',
      'Mumbai',
      'Maharashtra',
      '400001',
      'India'
    );
    insert propertyRecord;
    Test.setMock(HttpCalloutMock.class, new GeocodingMock(true));

    Test.startTest();
    new PropertyGeocodingService(propertyRecord.Id).execute(null);
    Test.stopTest();

    Property__c result = [
      SELECT Location__Latitude__s, Location__Longitude__s
      FROM Property__c
      WHERE Id = :propertyRecord.Id
    ];
    System.assertEquals(null, result.Location__Latitude__s);
    System.assertEquals(null, result.Location__Longitude__s);
  }

  @IsTest
  static void testMissingPropertyIdRaisesQueryException() {
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      new PropertyGeocodingService(null).execute(null);
    } catch (QueryException exceptionThrownByQuery) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'A missing property should surface the query exception.'
    );
  }
}
