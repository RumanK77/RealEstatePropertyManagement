import { LightningElement } from "lwc";
import getProperties from "@salesforce/apex/PropertyController.getProperties";

export default class PropertyList extends LightningElement {
  properties = [];
  totalRecords = 0;

  pageNumber = 1;
  pageSize = 25;

  minPrice;
  maxPrice;
  availabilityStatus = "";
  furnishingStatus = "";

  isLoading = false;

  distance;
  userLatitude;
  userLongitude;

  connectedCallback() {
    this.loadProperties();
  }

  async loadProperties() {
    this.isLoading = true;

    try {
      const result = await getProperties({
        pageNumber: this.pageNumber,
        pageSize: this.pageSize,
        minPrice: this.minPrice || null,
        maxPrice: this.maxPrice || null,
        availabilityStatus: this.availabilityStatus || null,
        furnishingStatus: this.furnishingStatus || null,
        userLatitude: this.userLatitude || null,
        userLongitude: this.userLongitude || null,
        distanceKm: this.distance ? Number(this.distance) : null
      });

      this.properties = result.properties;
      this.totalRecords = result.totalRecords;
      this.pageNumber = result.pageNumber;
      this.pageSize = result.pageSize;
    } catch (error) {
      console.error("Full error:", JSON.stringify(error));

      console.error("Error message:", error?.body?.message);

      console.error("Error details:", error);
    } finally {
      this.isLoading = false;
    }
  }

  handleFilterChange(event) {
    const { name, value } = event.target;

    this[name] = value;
  }

  async handleSearch() {
    this.pageNumber = 1;

    try {
      // Get location only when distance is entered
      if (this.distance) {
        this.isLoading = true;
        await this.getUserLocation();
      } else {
        this.userLatitude = null;
        this.userLongitude = null;
      }

      await this.loadProperties();
    } catch (error) {
      console.error("Error getting user location:", error);

      // We'll add proper toast messages next
      alert("Unable to get your location. Please allow location access.");
    } finally {
      this.isLoading = false;
    }
  }

  handlePrevious() {
    if (this.pageNumber > 1) {
      this.pageNumber--;
      this.loadProperties();
    }
  }

  handleNext() {
    if (this.pageNumber < this.totalPages) {
      this.pageNumber++;
      this.loadProperties();
    }
  }

  get totalPages() {
    return this.totalRecords > 0
      ? Math.ceil(this.totalRecords / this.pageSize)
      : 1;
  }

  get isPreviousDisabled() {
    return this.pageNumber <= 1;
  }

  get isNextDisabled() {
    return this.pageNumber >= this.totalPages;
  }

  get hasProperties() {
    return this.properties.length > 0;
  }

  get availabilityOptions() {
    return [
      { label: "All", value: "" },
      { label: "Available", value: "Available" },
      { label: "Occupied", value: "Occupied" }
    ];
  }

  get furnishingOptions() {
    return [
      { label: "All", value: "" },
      { label: "Furnished", value: "Furnished" },
      { label: "Semi-Furnished", value: "Semi-Furnished" },
      { label: "Unfurnished", value: "Unfurnished" }
    ];
  }

  getUserLocation() {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject("Geolocation is not supported by this browser.");
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (position) => {
          this.userLatitude = position.coords.latitude;
          this.userLongitude = position.coords.longitude;

          resolve();
        },
        (error) => {
          reject(error.message);
        }
      );
    });
  }
}
