# Steam Market Analytics: Finding the Game Dev "Sweet Spot"

## Project Overview
Analyzes a historical Steam dataset (27,075 games up to May 2019) using SQL, Power BI, and Excel to guide new game developers toward data-driven decisions. The analysis identifies the market "Sweet Spot" pinpointing genres, play modes, and pricing strategies that offer high revenue potential with minimal risk.

## Business Problem
Most games on Steam fail to generate meaningful revenue due to intense market competition. This project bridges creative vision and business strategy by identifying market saturation, pricing tiers, and top-performing genres to minimize financial risk.

## Data Source
* **Dataset:** [Steam Store Games (Clean dataset) on Kaggle](https://www.kaggle.com/datasets/nikdavis/steam-store-games?select=steam.csv)
* **Scope Note:** Only the primary `steam.csv` file was extracted and processed for this project. Supplementary tables in the dataset package were omitted as they lacked relevant or clean data necessary for this specific commercial analysis.

## Project Workflow
Raw Data -> MySQL (ETL & EDA) -> Power BI (Dashboard)

---

## Repository Structure

├── Dashboards/               # PNG screenshots of all Power BI dashboard views
├── Excel/                    # Excel workbook with dynamic dashboard & sensitivity model (.xlsx)
├── Power Bi/                 # Interactive Power BI file (.pbix) and exported PDF report
├── SQL/                      # SQL scripts for data cleaning, ETL, and EDA (.sql)
└── README.md                 # Main project documentation

## Project Architecture

### 1. SQL (Data Processing & EDA)
* **Cleaning & Normalization:** Filtered out low-quality titles (<100 ratings, 0 playtime), split multi-value attributes into normalized 1:N relational tables, handled missing values, and standardized company names.
* **Feature Engineering:** Calculated custom KPIs including playtime in hours, estimated revenue, positive review ratios, and price tiers.
* **Exploratory Data Analysis (EDA):** Executed multi-table joins and aggregation queries to evaluate genre distribution, publisher dominance, and revenue drivers.

### 2. Power BI (Interactive Reporting Suite)
* **Genre Popularity & Saturation:** Compared total game volume, player distribution, and ratings across genres to uncover market demand.
* **Monetization & Pricing Strategy:** Analyzed revenue distribution across price ranges ($0–$40+), genres, and play modes to identify optimal product strategies.
* **Industry Leaders:** Benchmarked top publishers and developers using dynamic parameter switching (Metric Choice & Dynamic Ranking).
* **Executive Summary:** Summarized strategic investment targets and actionable recommendations on a single page.

### 3. Excel (Dashboard & Sensitivity Model)
* **Dynamic Dashboard:** Built interactive charts with slicers for metric switching (Total vs. Average Revenue).
* **What-If Analysis:** Implemented a two-input Data Table simulating Profit/Loss based on sales growth and discount rates.

---

## Key Strategic Insights
* **The "Sweet Spot":** The lowest-risk game profile for an independent studio:
  * **Genre:** **FPS** or **RPG** (High average revenue, strong player engagement,and moderate competition).
  * **Price Range:** **$10.00 – $19.99** (Optimal balance between conversion rate and profit margin).
  * **Play Mode:** **Both (Singleplayer & Multiplayer)** (Maximizes audience reach and player retention).
* **High-Risk Categories:** Pure *Casual*, *Indie*, and *Adventure* titles face heavy saturation with low average revenue per game.

---

## How to Run

### Prerequisites
* **MySQL Server & MySQL Workbench** (or any SQL client)
* **Power BI Desktop**

1. **Download Raw Data:**
   * Download `steam.csv` directly from [Kaggle Dataset](https://www.kaggle.com/datasets/nikdavis/steam-store-games?select=steam.csv).

2. **Execute Database ETL & Analytics (SQL):**
   * Import `steam.csv` into your MySQL instance as a raw table named `steam`.
   * Open and execute `sql/01_data_cleaning.sql` to prepare data.
   * Open and execute `sql/02_exploratory_data_analysis.sql` to inspect aggregated market metrics and benchmarks.

3. **Explore Interactive Dashboards (Power BI):**
   * Open `powerbi/steam_market_analysis.pbix` in Power BI Desktop.
   * If prompted, adjust data source connections to point to your local MySQL database.
   * Navigate through the 4 dashboard pages (*Market Overview*, *Monetization*, *Publishers*, *Executive Summary*).