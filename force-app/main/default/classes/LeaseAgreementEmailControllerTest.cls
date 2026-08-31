@IsTest
private class LeaseAgreementEmailControllerTest {
  @TestSetup
  static void setupTestData() {
    Tenant__c tenantWithEmail = new Tenant__c(
      Name = 'Test Tenant With Email',
      Email__c = 'testtenant@example.com',
      Phone_Number__c = '9876543210'
    );

    Tenant__c tenantWithoutEmail = new Tenant__c(
      Name = 'Test Tenant Without Email',
      Phone_Number__c = '9876543211'
    );

    insert new List<Tenant__c>{ tenantWithEmail, tenantWithoutEmail };

    Property__c property = new Property__c(
      Name = 'Test Property',
      Address__c = '123 Test Street',
      City__c = 'Mumbai',
      State__c = 'Maharashtra',
      Postal_Code__c = '400001',
      Country__c = 'India',
      Type__c = 'Residential',
      Status__c = 'Available',
      Rent__c = 25000,
      Description__c = 'Test Property Description'
    );

    insert property;

    Lease_Agreement__c agreementWithEmail = new Lease_Agreement__c(
      Tenant__c = tenantWithEmail.Id,
      Property__c = property.Id,
      Terms__c = '12 Month Lease Agreement',
      Agreed_Monthly_Rent__c = 25000,
      Start_Date__c = Date.today(),
      End_Date__c = Date.today().addMonths(12)
    );

    Lease_Agreement__c agreementWithoutEmail = new Lease_Agreement__c(
      Tenant__c = tenantWithoutEmail.Id,
      Property__c = property.Id,
      Terms__c = '12 Month Lease Agreement',
      Agreed_Monthly_Rent__c = 25000,
      Start_Date__c = Date.today(),
      End_Date__c = Date.today().addMonths(12)
    );

    insert new List<Lease_Agreement__c>{
      agreementWithEmail,
      agreementWithoutEmail
    };
  }

  @IsTest
  static void testSendLeaseAgreementPdf_Success() {
    Lease_Agreement__c agreement = [
      SELECT Id
      FROM Lease_Agreement__c
      WHERE Tenant__r.Email__c = 'testtenant@example.com'
      LIMIT 1
    ];

    String pdfBase64 = EncodingUtil.base64Encode(
      Blob.valueOf('Test PDF Content')
    );

    Test.startTest();

    LeaseAgreementEmailController.sendLeaseAgreementPdf(
      agreement.Id,
      pdfBase64,
      'LeaseAgreement.pdf'
    );

    System.assertEquals(
      1,
      Limits.getEmailInvocations(),
      'One email should be sent.'
    );

    Test.stopTest();
  }

  @IsTest
  static void testSendLeaseAgreementPdf_TenantWithoutEmail() {
    Lease_Agreement__c agreement = [
      SELECT Id
      FROM Lease_Agreement__c
      WHERE Tenant__c != NULL AND Tenant__r.Email__c = NULL
      LIMIT 1
    ];

    String pdfBase64 = EncodingUtil.base64Encode(
      Blob.valueOf('Test PDF Content')
    );

    Test.startTest();

    Boolean exceptionThrown = false;

    try {
      LeaseAgreementEmailController.sendLeaseAgreementPdf(
        agreement.Id,
        pdfBase64,
        'LeaseAgreement.pdf'
      );
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }

    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'An AuraHandledException should be thrown when Tenant email is missing.'
    );
  }
}
