import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createPropertyWithImages from "@salesforce/apex/PropertyFormController.createPropertyWithImages";

export default class PropertyForm extends LightningElement {
  propertyData = {
    Name: "",
    Address__c: "",
    City__c: "",
    State__c: "",
    Postal_Code__c: "",
    Country__c: "",
    Type__c: "",
    Furnishing_Status__c: "",
    Status__c: "",
    Rent__c: null,
    Description__c: ""
  };

  selectedFiles = [];
  isLoading = false;

  handleInputChange(event) {
    const fieldName = event.target.name;
    const value = event.target.value;

    this.propertyData = {
      ...this.propertyData,
      [fieldName]: value
    };
  }

  handleFileChange(event) {
    const files = Array.from(event.target.files);

    const maxFileSize = 2 * 1024 * 1024; // 2 MB

    const invalidFile = files.find((file) => file.size > maxFileSize);

    if (invalidFile) {
      this.showToast(
        "File Too Large",
        "Each image must be smaller than 2 MB.",
        "error"
      );

      this.selectedFiles = [];
      event.target.value = null;
      return;
    }

    this.selectedFiles = files;
  }

  async handleCreateProperty() {
    const allInputs = this.template.querySelectorAll(
      "lightning-input, lightning-combobox, lightning-textarea"
    );

    const isValid = [...allInputs].reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);

    if (!isValid) {
      return;
    }

    // Validate images
    if (this.selectedFiles.length === 0) {
      this.showToast(
        "Image Required",
        "Please select at least one property image.",
        "error"
      );
      return;
    }

    this.isLoading = true;

    try {
      // Convert all selected files to Base64
      const files = await Promise.all(
        this.selectedFiles.map((file) => this.convertFileToBase64(file))
      );

      // Call Apex
      const propertyId = await createPropertyWithImages({
        propertyRecord: this.propertyData,
        files: files
      });

      this.showToast(
        "Success",
        "Property and images created successfully.",
        "success"
      );

      console.log("Created Property Id:", propertyId);

      this.resetForm();
    } catch (error) {
      console.error(error);

      this.showToast("Error", this.getErrorMessage(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  convertFileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = () => {
        const base64Data = reader.result.split(",")[1];

        resolve({
          fileName: file.name,
          base64Data: base64Data
        });
      };

      reader.onerror = () => reject(reader.error);

      reader.readAsDataURL(file);
    });
  }

  resetForm() {
    this.propertyData = {
      Name: "",
      Address__c: "",
      City__c: "",
      State__c: "",
      Postal_Code__c: "",
      Country__c: "",
      Type__c: "",
      Furnishing_Status__c: "",
      Status__c: "",
      Rent__c: null,
      Description__c: ""
    };

    this.selectedFiles = [];

    // Clear file input
    const fileInput = this.template.querySelector(
      'lightning-input[data-id="imageInput"]'
    );

    if (fileInput) {
      fileInput.value = null;
    }
  }

  getErrorMessage(error) {
    if (error?.body?.message) {
      return error.body.message;
    }

    return "An unexpected error occurred.";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
  get typeOptions() {
    return [
      { label: "Residential", value: "Residential" },
      { label: "Commercial", value: "Commercial" }
    ];
  }

  get furnishingOptions() {
    return [
      { label: "Furnished", value: "Furnished" },
      { label: "Semi-Furnished", value: "Semi-Furnished" },
      { label: "Unfurnished", value: "Unfurnished" }
    ];
  }

  get statusOptions() {
    return [
      { label: "Available", value: "Available" },
      { label: "Occupied", value: "Occupied" }
    ];
  }
  get hasSelectedFiles() {
    return this.selectedFiles.length > 0;
  }
}
