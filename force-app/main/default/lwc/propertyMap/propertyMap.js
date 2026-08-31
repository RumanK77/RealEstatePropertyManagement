import { LightningElement, api, wire } from "lwc";
import getPropertyLocation from "@salesforce/apex/PropertyMapController.getPropertyLocation";

export default class PropertyMap extends LightningElement {
  @api recordId;

  latitude;
  longitude;
  propertyName;
  error;

  @wire(getPropertyLocation, { propertyId: "$recordId" })
  wiredLocation({ data, error }) {
    if (data) {
      console.log("Property Location:", JSON.stringify(data));

      this.latitude = data.latitude;
      this.longitude = data.longitude;
      this.propertyName = data.propertyName;
      this.error = undefined;
    } else if (error) {
      console.error("Error:", JSON.stringify(error));

      this.error = error;
      this.latitude = undefined;
      this.longitude = undefined;
    }
  }

  get hasLocation() {
    return (
      this.latitude !== undefined &&
      this.latitude !== null &&
      this.longitude !== undefined &&
      this.longitude !== null
    );
  }

  get mapMarkers() {
    return [
      {
        location: {
          Latitude: this.latitude,
          Longitude: this.longitude
        },
        title: this.propertyName,
        description: "Property Location"
      }
    ];
  }
}
