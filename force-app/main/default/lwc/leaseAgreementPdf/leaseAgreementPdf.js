import { LightningElement, api, wire } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import pdfGeneration from "@salesforce/resourceUrl/pdfGeneration";
import { getRecord } from "lightning/uiRecordApi";
import { CurrentPageReference } from "lightning/navigation";

import sendLeaseAgreementPdf from "@salesforce/apex/LeaseAgreementEmailController.sendLeaseAgreementPdf";

import { ShowToastEvent } from "lightning/platformShowToastEvent";

// Lease Agreement fields
import LEASE_NUMBER from "@salesforce/schema/Lease_Agreement__c.Name";
import TENANT_NAME from "@salesforce/schema/Lease_Agreement__c.Tenant__r.Name";
import PROPERTY_NAME from "@salesforce/schema/Lease_Agreement__c.Property__r.Name";
import TERMS from "@salesforce/schema/Lease_Agreement__c.Terms__c";
import MONTHLY_RENT from "@salesforce/schema/Lease_Agreement__c.Agreed_Monthly_Rent__c";
import START_DATE from "@salesforce/schema/Lease_Agreement__c.Start_Date__c";
import END_DATE from "@salesforce/schema/Lease_Agreement__c.End_Date__c";

const FIELDS = [
  LEASE_NUMBER,
  TENANT_NAME,
  PROPERTY_NAME,
  TERMS,
  MONTHLY_RENT,
  START_DATE,
  END_DATE
];

export default class LeaseAgreementPdf extends LightningElement {
  @api recordId;

  pageRecordId;
  recordData;

  jsPdfInitialized = false;
  isPdfLoaded = false;
  isSending = false;

  // Get record ID from page context
  @wire(CurrentPageReference)
  getCurrentPageReference(pageRef) {
    if (pageRef) {
      this.pageRecordId = pageRef.attributes?.recordId;
    }
  }

  // Use normal recordId, otherwise CurrentPageReference
  get effectiveRecordId() {
    return this.recordId || this.pageRecordId;
  }

  @wire(getRecord, {
    recordId: "$effectiveRecordId",
    fields: FIELDS
  })
  wiredLeaseAgreement({ error, data }) {
    if (data) {
      this.recordData = data;
      console.log("Lease Agreement data loaded successfully");
    } else if (error) {
      console.error("Error loading Lease Agreement:", error);
    }
  }

  renderedCallback() {
    if (this.jsPdfInitialized) {
      return;
    }

    this.jsPdfInitialized = true;

    loadScript(this, pdfGeneration)
      .then(() => {
        this.isPdfLoaded = true;
        console.log("jsPDF loaded successfully");
      })
      .catch((error) => {
        console.error("Error loading jsPDF:", error);
      });
  }

  // ===============================
  // CREATE PDF - REUSABLE METHOD
  // ===============================
  createPdf() {
    if (!this.effectiveRecordId) {
      throw new Error("Record ID is missing");
    }

    if (!this.recordData) {
      throw new Error("Lease Agreement data is not loaded");
    }

    if (!this.isPdfLoaded) {
      throw new Error("PDF library is not loaded yet");
    }

    const { jsPDF } = window.jspdf;
    const doc = new jsPDF();

    const fields = this.recordData.fields;

    const leaseNumber = fields.Name.value || "N/A";

    const tenant = fields.Tenant__r?.value?.fields?.Name?.value || "N/A";

    const property = fields.Property__r?.value?.fields?.Name?.value || "N/A";

    const terms = fields.Terms__c.value || "N/A";

    const monthlyRent = fields.Agreed_Monthly_Rent__c.value || 0;

    const startDate = fields.Start_Date__c.value || "N/A";

    const endDate = fields.End_Date__c.value || "N/A";

    // Format currency
    const formattedRent = `INR ${new Intl.NumberFormat("en-IN", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(monthlyRent)}`;

    // Format dates
    const formatDate = (dateValue) => {
      if (!dateValue || dateValue === "N/A") {
        return "N/A";
      }

      return new Intl.DateTimeFormat("en-IN", {
        year: "numeric",
        month: "long",
        day: "numeric"
      }).format(new Date(dateValue + "T00:00:00"));
    };

    const formattedStartDate = formatDate(startDate);
    const formattedEndDate = formatDate(endDate);

    // ===== HEADER =====
    doc.setFontSize(24);
    doc.setFont("helvetica", "bold");
    doc.text("LEASE AGREEMENT", 105, 25, { align: "center" });

    // Divider
    doc.setLineWidth(0.5);
    doc.line(20, 32, 190, 32);

    // ===== AGREEMENT DETAILS =====
    doc.setFontSize(16);
    doc.setFont("helvetica", "bold");
    doc.text("Agreement Details", 20, 48);

    const details = [
      ["Lease Agreement Number", leaseNumber],
      ["Tenant", tenant],
      ["Property", property],
      ["Terms", terms],
      ["Monthly Rent", formattedRent],
      ["Start Date", formattedStartDate],
      ["End Date", formattedEndDate]
    ];

    let yPosition = 62;

    details.forEach(([label, value]) => {
      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      doc.text(`${label}:`, 25, yPosition);

      doc.setFont("helvetica", "normal");
      doc.text(String(value), 85, yPosition);

      yPosition += 13;
    });

    // ===== FOOTER =====
    doc.setLineWidth(0.3);
    doc.line(20, 270, 190, 270);

    doc.setFontSize(9);
    doc.setFont("helvetica", "normal");

    doc.text(
      `Generated on: ${new Date().toLocaleDateString("en-IN")}`,
      20,
      280
    );

    doc.text("Real Estate Property Management System", 190, 280, {
      align: "right"
    });

    return {
      doc,
      leaseNumber
    };
  }

  // ===============================
  // DOWNLOAD PDF
  // ===============================
  generatePdf() {
    try {
      const { doc, leaseNumber } = this.createPdf();

      doc.save(`LeaseAgreement-${leaseNumber}.pdf`);
    } catch (error) {
      console.error("PDF generation error:", error);

      this.showToast("Error", error.message, "error");
    }
  }

  // ===============================
  // SEND PDF TO TENANT
  // ===============================
  async sendPdfToTenant() {
    try {
      this.isSending = true;

      const { doc, leaseNumber } = this.createPdf();

      // Convert PDF to Base64
      const pdfBase64 = doc.output("datauristring").split(",")[1];

      const fileName = `LeaseAgreement-${leaseNumber}.pdf`;

      await sendLeaseAgreementPdf({
        leaseAgreementId: this.effectiveRecordId,
        pdfBase64: pdfBase64,
        fileName: fileName
      });

      this.showToast(
        "Success",
        "Lease Agreement PDF sent successfully to the Tenant.",
        "success"
      );
    } catch (error) {
      console.error("Error sending PDF:", error);

      const errorMessage =
        error?.body?.message ||
        error?.message ||
        "An error occurred while sending the PDF.";

      this.showToast("Error", errorMessage, "error");
    } finally {
      this.isSending = false;
    }
  }

  // ===============================
  // SHOW TOAST
  // ===============================
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
