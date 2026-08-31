public with sharing class LeaseAgreementEmailController {
  @AuraEnabled
  public static void sendLeaseAgreementPdf(
    Id leaseAgreementId,
    String pdfBase64,
    String fileName
  ) {
    Lease_Agreement__c agreement = [
      SELECT Id, Name, Tenant__c, Tenant__r.Name, Tenant__r.Email__c
      FROM Lease_Agreement__c
      WHERE Id = :leaseAgreementId
      LIMIT 1
    ];

    if (agreement.Tenant__c == null) {
      throw new AuraHandledException(
        'No Tenant is associated with this Lease Agreement.'
      );
    }

    if (String.isBlank(agreement.Tenant__r.Email__c)) {
      throw new AuraHandledException(
        'The Tenant does not have an email address.'
      );
    }

    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();

    attachment.setFileName(fileName);
    attachment.setBody(EncodingUtil.base64Decode(pdfBase64));
    attachment.setContentType('application/pdf');

    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

    email.setToAddresses(new List<String>{ agreement.Tenant__r.Email__c });

    email.setSubject('Lease Agreement - ' + agreement.Name);

    email.setPlainTextBody(
      'Dear ' +
        agreement.Tenant__r.Name +
        ',\n\n' +
        'Please find your Lease Agreement attached to this email.\n\n' +
        'Regards,\n' +
        'Real Estate Property Management'
    );

    email.setFileAttachments(
      new List<Messaging.EmailFileAttachment>{ attachment }
    );

    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
  }
}
