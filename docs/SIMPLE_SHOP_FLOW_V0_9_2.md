# ShopDesk Pro v0.9.2 — Simplified products and POS

## Exactly what the shopkeeper does

1. **Categories:** Add Mattress, Chatai, Door Mat, Floor Paper, Table Sheet, Blanket, etc. No dynamic field designer needed.
2. **Products:** Choose category and enter product name.
3. **Variations:** Open product → Add Size / Variation → optional Size, Color, Design, Quality. Select how goods come from supplier:
   - **Single Piece:** track pieces.
   - **Set:** enter pieces per set (example 3). Buy sets, sell sets or loose pieces.
   - **Packet:** enter pieces per packet (example 12). Buy packets, sell packets or loose pieces.
   - **Roll:** enter feet per roll (example 100) and feet per gazz (default 3, editable). Buy rolls, sell rolls/feet/gazz.
4. **POS:** Tap product, pick size/color (when multiple), pick **Purchase as / Sell as** unit; enter quantity and **manual price per selected unit**. Save bill. No automatic print dialog.

### Worked examples
- 2 sets × 3 pieces = **6 pieces**. Sell 4 pieces → **2 pieces remaining**.
- 2 packets × 12 pieces = **24 pieces**. Sell 7 loose → **17 pieces remaining**.
- 1 roll × 100 feet = **100 feet**. Sell 5 gazz at 3 feet/gazz → **85 feet remaining**.

### Internal details (not shown to shopkeeper)
Each variation gets an automatically generated SKU. Base inventory is stored in pieces or feet. Set, Packet, Roll and Gazz conversion factors are saved with invoice lines so historical transactions do not change when product setup changes later.

### Existing database
This release **does not silently delete any demo or live database**. Existing SQLite categories/products/variants remain usable. To try a clean demo, use the app's first-launch Create New Database flow with a separate test installation/data location. Always save a backup before resetting an existing installation. Licensing and 48-hour trial are separate from demo stock; resetting shop records should not be used to reset license terms.

### Status
Source updated, not Windows-compiled in this environment. GitHub Actions must pass static analysis, database/UI tests and Windows bundle build before treating this as a working release. Run an end-to-end sale/purchase/void/return test with sample shop data before using on live stock.
