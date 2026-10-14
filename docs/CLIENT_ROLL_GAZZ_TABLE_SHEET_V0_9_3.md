# ShopDesk Pro v0.9.3 — Simple client workflow

### Categories / Products / Variations
1. Create Category, create Product, select Add Variation.
2. Fill optional Size / Color / Design / Quality.
3. Choose Pieces, Set, Packet or Roll. Set/Packet sizes can be 3, 5, 7, 9, 12 or any whole number.
4. Roll: enter **How many Gazz in one Roll?** and **Roll quantity**. ShopDesk converts Feet internally using 1 Gazz = 3 Feet.
5. For rolls that are sold as Table Sheets, check **Sell this Roll as Table Sheets too** and enter **Gazz used for 1 Table Sheet**.
6. POS: select Product -> choose Size/Color/Variation dropdown -> select selling unit (Table Sheet, Gazz, Feet, Roll, Set, Packet, Piece) -> manually enter quantity/price.

### Examples
- 2 Rolls x 30 Gazz/Roll = 60 Gazz = 180 Feet in stock. Selling 4 Table Sheets at 2 Gazz each deducts 24 Feet -> 156 Feet remains.
- 1 Roll x 30 Gazz = 90 Feet; selling 5 Gazz deducts 15 Feet -> 75 Feet.
- 2 Packets x 12 Pieces = 24 Pieces; selling 7 loose Pieces leaves 17 Pieces.
- Set of 3, 5, 7, 9 each has its own variation and separate stock.

### Limits and safety
- Gazz is configured as 3 Feet in the simple form; changing local Gazz measurement needs a future setting / extension.
- Table Sheet is a fixed-length cut per variation. Create a separate variation for a different Table Sheet size.
- Historical documents snapshot purchase/sale conversion factors. Existing stock is not automatically converted.
- Existing negative stock behavior is preserved.
- Demo database: create a new database after backup if you want a clean catalog.
- **The Windows build and Flutter analyzer have not been executed in this environment.** Run the included GitHub Actions workflow, then test on a copy of the demo database.
