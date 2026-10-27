# 6. Content catalog

The catalog is a JSON file bundled with the app (`Rumbo/Resources/catalog/content.json`). Each time the Library opens (or is pulled to refresh), Rumbo fetches `https://raw.githubusercontent.com/rahns/rumbo/main/Rumbo/Resources/catalog/content.json`, caches it, and uses it only if its `version` is higher than the bundled one. So suggestions can be updated by editing the file on `main` and bumping `version`, without a new build. Free, no server.

Each item: `id`, `title`, `kind` (`series` / `film` / `podcast` / `youtube`), `from` and `to` bands, `country`, `whereToFind`, optional `url`, `why`. A RumboCore test checks that the bundled file decodes, ids are unique and every band has something.

## 6.1 Core sources

| Source | Units | Used in bands | How it's scheduled |
|---|---|---|---|
| Dreaming Spanish | Hours; difficulty range | All | `ds.watch` / `ds.easy`, difficulty tuned by comprehension ratings |
| Language Transfer – Complete Spanish | 90 tracks | Until finished (target: by end of B1.1) | One track per language-focused slot; shaky → repeat once |
| Extra en Español | 13 episodes | A2 intensive (2 parts per episode), B1 extensive | Weekly change of pace from Dreaming Spanish (A2: 1 part/week; B1: 1 episode/week), only on days with 20+ min |
| Duolingo | Sections/units | A2.1–B1.2, optional B2.1 | 5-min warm-up, never longer |
| Writing | Prompt library (`RumboCore/PromptLibrary+*.swift`): 100 guided-writing prompts per level (A2, B1, B2), 100 quick-write topics, 63 4/3/2 stories, 75 travel missions | All | `write.guided`, `write.quick`; a prompt isn't repeated until its whole list has been used |
| Tandem | 62 prompts per level (A2, B1, B2), each with something to send and a question back | All | Text → voice → calls; no repeats until the list is used up |

## 6.2 Suggested content

Leaning Latin American, since the goal is living there. Each entry has a band, format, country/accent, where to find it, and why it's suggested.

| Band | Title | Format | Accent | Why |
|---|---|---|---|---|
| A2.1–A2.2 | *Peppa Pig* (Latin American dub) | Cartoon, YouTube | Various | Short, very clear, everyday life |
| A2.1–B1.1 | *Destinos* | Learner telenovela (52 episodes; no longer free online, some PBS stations) | Mexico, others | Made for learners; a story that rewards daily watching |
| A2.2–B1.1 | *Coco*, *Encanto* (Latin American dub) | Film | Mexico, Colombia | Familiar stories, clear speech; songs for shadowing |
| A2.2–B1.2 | *Duolingo Spanish Podcast* | Podcast | Various | True stories in slow, clear Spanish |
| B1.1–B1.2 | *Easy Spanish* | YouTube street interviews | Various | Real speakers with dual subtitles; many accents |
| B1.1–B1.2 | *Españolistos* | Podcast | Colombia | Built for intermediate learners; good for travel days |
| B1.1–B1.2 | *Español con Juan* | YouTube | Spain | Grammar and culture, all in Spanish |
| B1.1–B2.1 | *Notes in Spanish* | Podcast | Spain | Real conversations, intermediate to advanced |
| B1.2–B2.1 | *Club de Cuervos* | TV series | Mexico | Comedy-drama, everyday register |
| B2.1–B2.2 | *Radio Ambulante* | Narrative podcast | Various | Gold-standard stories; transcripts help the stretch |
| B2.1–B2.2 | *El Hilo* | News podcast | Various | Current events; vocabulary for living there |
| B2.1–B2.2 | *Luis Miguel: La Serie* | TV series | Mexico | Strong narrative pull for extensive viewing |
| B2.1–B2.2 | *La Casa de Papel* | TV series | Spain | Addictive; a contrast to Latin American accents |
| B2.1–B2.2 | *Roma* | Film | Mexico | Quiet everyday speech, slow enough to follow |
| B2.2 | *La Casa de las Flores* | TV series | Mexico | Fast, funny, idiomatic |
| B2.2 | *El Marginal* | TV series | Argentina | Heavy slang and voseo; a real challenge |

The Library shows what suits the learner's band now and what comes next. **Watch this** marks one item as the current show; `content.watch` tasks (planned when Extra en Español has run out or isn't used from B1, or when there's no Dreaming Spanish) name it and offer an Open button. Within each list, the easiest comes first.
