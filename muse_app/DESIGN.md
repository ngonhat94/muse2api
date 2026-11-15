# Muse dashboard design
## Authority
User-pinned 9Router dashboard direction, applied to native Flutter rather than a website imitation.
Reference: https://github.com/decolua/9router/blob/1fe586bb/README.md
Screenshot visually inspected: https://raw.githubusercontent.com/decolua/9router/1fe586bb/images/9router.png
## System
Neutral low-glare canvas #111113, surface #19191C, raised #232326, borders #38383F. Foreground #F2F2F3, muted #B1B1BA. Warm peach #F4A27C identifies selected navigation and primary actions; #382923 is its selected ground. Green #86D9AC is reserved for confirmed health and cached remaining quota, always with textual meaning.
Native system sans, 26px page headings, 17px account titles, 13–16px supporting data. 8/16/24 spacing rhythm. Flat thin-bordered 10px cards; 8px navigation corners. No glows, gradients, or decorative charts.
## Account surface (Operate)
Fixed 248px desktop sidebar with Muse identity, clear selected row, divider and persistent destinations. Below 800px retain labeled native bottom navigation and More sheet. Account page leads with title and cached-data explanation, compact pool counts and account records. Cached quota is adjacent to its account; remaining-week bar is accompanied by exact text and never shown for unknown data. All existing actions and confirmation flows remain intact.
## Verification
Use fixture-only/disconnected renders; never launch real Muse probes for visual validation. Test narrow layout with large text and the full existing behavior suite.
