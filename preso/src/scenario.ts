/** Illustrative Contoso lab journey for the animated diagrams. */
export const lab = {
  host: "http://34.18.109.143",
  web: "ShipmentsWeb",
  tracking: "TrackingApi-EDOT",
  businessCs: "Contoso.Shipments.Business",
  businessVb: "Contoso.Shipments.LegacyVb",
  observability: "Contoso.Observability",
  checkout: "POST Checkout/Index",
  vbSpan: "LegacyShipmentService.EnrichQuoteNote",
  csSpan: "ShipmentService.CreateQuoteAsync",
  labels: ["tracking_id", "lane", "weight_kg", "quote_price"],
} as const;
