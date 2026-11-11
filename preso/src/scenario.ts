/** Illustrative Contoso lab journey for the animated diagrams. */
export const lab = {
  /** Public docs use paths only — no live lab host in the deck. */
  checkoutPath: "/web/Checkout",
  trackingPath: "/tracking/api/tracking/{id}",
  web: "ShipmentsWeb",
  tracking: "TrackingApi-EDOT",
  businessCs: "Contoso.Shipments.Business",
  businessVb: "Contoso.Shipments.LegacyVb",
  observability: "Contoso.Observability",
  checkout: "POST Checkout/Index",
  vbSpan: "LegacyShipmentService.EnrichQuoteNote",
  csSpan: "ShipmentService.CreateQuoteAsync",
  labels: ["tracking_id", "lane", "weight_kg", "quote_price"],
  repo: "https://github.com/ziftech/dotnetapm",
} as const;
