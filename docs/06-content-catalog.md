# 6. Content catalog

The catalog is a JSON file bundled with the app (`Resources/catalog/content.json`). Rumbo also checks for a newer copy at `https://raw.githubusercontent.com/rahns/rumbo/main/catalog/content.json` when online, so suggestions can be updated without a new build. Free, no server.

## 6.1 Core sources

| Source | Units | Used in bands | How it's scheduled |
|---|---|---|---|
| Dreaming Spanish | Hours; difficulty range | All | `ds.watch` / `ds.easy`, difficulty tuned by comprehension ratings |
| Language Transfer – Complete Spanish | 90 tracks | Until finished (target: by end of B1.1) | One track per language-focused slot; shaky → repeat once |
| Extra en Español | 13 episodes | A2 intensive (2 parts per episode), B1 extensive | 1 episode/week anchor |
| Duolingo | Sections/units | A2.1–B1.2, optional B2.1 | 5-min warm-up |
| Writing | Prompt library, ~40 prompts per band | All | `write.guided`, `write.quick` |
| Tandem | Prompt library per stage | All | Text → voice → calls |

## 6.2 Suggested content

Leaning Latin American, since the goal is living there. Each entry has a band, format, country/accent, where to find it, and why it's suggested.

| Band | Title | Format | Accent | Why |
|---|---|---|---|---|
| A2.2–B1.1 | *Destinos* | Learner telenovela (52 episodes) | Mexico, others | Made for learners; a story that rewards daily watching |
| A2.2–B1.1 | Pixar/Disney films, Latin American dub (*Coco*, *Encanto*) | Film | Mexico, Colombia | Familiar stories, clear speech, Spanish subtitles available |
| B1.1 | *Easy Spanish* | YouTube street interviews | Mexico, Argentina, Colombia… | Real speakers with dual subtitles; hear many accents |
| B1.1–B1.2 | *Españolistos* | Podcast | Colombia | Built for intermediate learners; good for travel days |
| B1.2 | *No Hay Tos* | Podcast | Colombia | Intermediate, natural pace, transcripts |
| B1.2–B2.1 | *Club de Cuervos* | TV series | Mexico | Comedy-drama, everyday register |
| B2.1 | *Radio Ambulante* | Narrative podcast | All of Latin America | Gold-standard stories; transcripts help the stretch |
| B2.1 | *Luis Miguel: La Serie* | TV series | Mexico | Strong narrative pull for extensive viewing |
| B2.1–B2.2 | *El Hilo* | News podcast | Latin America | Current events; topic vocabulary for living there |
| B2.2 | *La Casa de las Flores* | TV series | Mexico | Fast, funny, idiomatic |
| B2.2 | *El Marginal* | TV series | Argentina | Heavy slang; a real challenge |

Suggestions show up in the Library when the learner reaches the band, and are planned automatically into input slots when Extra en Español or another input source is finished. When the learner picks a destination country in Settings, content with that accent is shown first.
