public with sharing class PropertyFormController {
  public class FileData {
    @AuraEnabled
    public String fileName { get; set; }

    @AuraEnabled
    public String base64Data { get; set; }
  }

  @AuraEnabled
  public static Id createPropertyWithImages(
    Property__c propertyRecord,
    List<FileData> files
  ) {
    if (propertyRecord == null) {
      throw new AuraHandledException('Property details are required.');
    }

    if (files == null || files.isEmpty()) {
      throw new AuraHandledException(
        'At least one property image is required.'
      );
    }

    List<ContentVersion> contentVersions = new List<ContentVersion>();

    for (FileData fileData : files) {
      if (
        fileData != null &&
        !String.isBlank(fileData.fileName) &&
        !String.isBlank(fileData.base64Data)
      ) {
        String title = fileData.fileName;

        if (fileData.fileName.contains('.')) {
          title = fileData.fileName.substringBeforeLast('.');
        }

        contentVersions.add(
          new ContentVersion(
            Title = title,
            PathOnClient = fileData.fileName,
            VersionData = EncodingUtil.base64Decode(fileData.base64Data)
          )
        );
      }
    }

    if (contentVersions.isEmpty()) {
      throw new AuraHandledException(
        'At least one valid property image is required.'
      );
    }

    Savepoint sp = Database.setSavepoint();

    try {
      // Create the Property
      insert propertyRecord;

      // Create Files
      insert contentVersions;

      // Get ContentDocument IDs
      List<ContentVersion> insertedVersions = [
        SELECT Id, ContentDocumentId
        FROM ContentVersion
        WHERE Id IN :contentVersions
      ];

      List<ContentDocumentLink> links = new List<ContentDocumentLink>();

      for (ContentVersion version : insertedVersions) {
        links.add(
          new ContentDocumentLink(
            ContentDocumentId = version.ContentDocumentId,
            LinkedEntityId = propertyRecord.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
          )
        );
      }

      insert links;

      // Geocode property address asynchronously
      System.enqueueJob(new PropertyGeocodingService(propertyRecord.Id));

      return propertyRecord.Id;
    } catch (Exception e) {
      Database.rollback(sp);

      throw new AuraHandledException(
        'Unable to create property. Please try again.'
      );
    }
  }
}
