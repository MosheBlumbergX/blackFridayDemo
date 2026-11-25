# Findings

First real run: 25 November 2026, two days before Black Friday. Full output: `logs/run-1.log`.

## Headline

Five Christmas gift ideas went in. The Flink agent searched real UK shop prices through its MCP tool and returned five verdicts:

| Product | Verdict | Cheapest | Median | Shop |
|---|---|---|---|---|
| Apple AirPods Pro | BEST_DEAL | 154.80 | 183.99 | SilentSale |
| Nintendo Switch 2 | OK_PRICE | 399.99 | 440.99 | Smyths Toys |
| LEGO City advent calendar | BEST_DEAL | 18.39 | 26.13 | Roys Wroxham |
| Dyson Airwrap | BEST_DEAL | 299.99 | 355.36 | Dyson UK |
| Ninja air fryer | NO_DATA | - | - | fewer than 4 comparable listings |

**3 of 5 products had a genuine best deal, 1 was an ordinary price, 1 had too little data, and 0 fake discounts were found.** Prices are in GBP as seen on the run date and will change.

The verdicts match the rules in the agent prompt (BEST_DEAL needs the cheapest listing at least 10% below the median of at least 3 comparable listings; FAKE_DISCOUNT needs a claimed saving of 20% or more with the price less than 5% below the median). Dyson UK's claimed saving (25% off a stated old price) was real, because its price was also 15.6% below the median, so it was not flagged as fake.

## What surprised me

1. **Raw shopping results are not safe to judge.** The first real search for "PlayStation 5 console" returned a 40.22 "Sony Playstation Console" from eBay as the cheapest item. Unfiltered, the agent would have announced a 78% "best ever deal" on an old or used console. The first fix was to drop second-hand listings, marketplaces, resale shops, importers and third-party sellers, require every word of the query in the title, and trim prices below half the median.
2. **Query wording decides everything.** "LEGO advent calendar" matched nothing relevant, while "LEGO City advent calendar" gave 14 comparable listings. "PlayStation 5 console" and "Samsung 55 inch 4K TV" gave nothing usable after filtering. I swapped in products that worked and kept the Ninja air fryer as an honest NO_DATA case.
3. **The model does not do the sums.** The Lambda computes the median, the gap and the claimed saving, and the agent only applies the rules. The numbers in the verdicts above are the Lambda's.
4. **"Sent" is not "delivered", and "delivered" is not "seen".** The tool returned success and the agent said it had sent the alerts, but nothing appeared in the inbox. The Lambda logs and SES statistics showed the mail was sent and accepted, with no bounces. All six alerts from two runs were sitting in the Spam folder. SES sends from an address identity with no DKIM or SPF for its domain, and Gmail treats that as suspicious. The model cannot know any of this, so the demo does not claim delivery. For a real deployment, verify a domain in SES with DKIM.
5. **Small shops can win.** The AirPods "best deal" is at a small shop (SilentSale), and 4 listings make a thin median. Treat these as leads to check, not a guarantee of a good retailer.

## Cost

About 26 SerpAPI searches were used in total, including all testing, out of 250 on the free plan. Each run costs 5 searches.

## Not verified

- **Latency per product:** the runs were not timed, so no latency figure is claimed.
- **FAKE_DISCOUNT path:** no product triggered it on real data, so that branch of the agent's rules has not been exercised. The deal and no-data paths were.
