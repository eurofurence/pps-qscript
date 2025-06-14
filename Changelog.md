
## 2026-06-09
 * extend filtering of filenames for actor scripts

## 2025-05-15
 * more detail in no Stagehand warning

## 2025-05-13
 * fix "People Export" for empty scenes

## 2025-05-11
 * keep track of TechProp "Curtain"

## 2025-05-10
 * preserve order of scenes from index.wiki
 * add nobody to bad roles
 * warn on spoken lines without voice
 * detect bad role names on ACT too

## 2025-05-08
 * detect bad role names earlier

## 2025-05-07
 * allow puppets without a builder
 * fix alt tag on puppet images

## 2025-05-04
 * skip hands 'None' only for the current scene
 * allow '. ' in prop names
 * add extra BOM to some CSV output files
 * migrate "puppet_pool.csv" to "puppet_pool.json"
 * track mutiple hands in "assignment_list.csv"

## 2025-03-10
 * allow more UTF-8 characters in names

## 2025-01-28
 * add target for switching to a new show

## 2025-01-19
 * cleanup html to follow current standard

## 2024-09-26
 * new config option to filter intro

## 2024-09-09
 * strip spaces from actor files

## 2024-09-01
 * support extra colors for patterns
 * get ini files from wiki
 * ini files are now optional

## 2024-08-26
 * support RATS header
 * add stagehand for Curtain

## 2024-08-05
 * support more lines in the header of a scene

## 2024-07-22
 * warn if a puppet is not in the pool

## 2024-06-17
 * create "plain.wiki" without dark mode
   for viewing the script inside dokuwiki

## 2024-05-27
 * new config option: report_untagged
   warn if a possible untagged prop is found

## 2024-05-14
 * skip emtpy columns in availability.csv

## 2024-05-09
 * fix highlite with ' in names
 * fix regression with ' in names

## 2024-05-07
 * generate separate rows when a prop needs more than one hand
   in 'People export' and 'assignment-list.csv'.

## 2024-04-08
 * allow cyrillic a in names

## 2024-03-19
 * credit mutiple puppet builders

## 2024-02-04
 * allow ' in names

## 2023-08-81
 * fix highlite with name's

## 2023-06-24
 * fix availability.html with unseen actors

## 2023-06-16
 * parse prerec tables for cast and hightlite

## 2023-06-12
 * fix error on spotlight token
 * fix escape for table 'Todo List' in out.html

## 2023-06-11
 * list of scenes from config
 * use YAML config files for highlite

## 2023-06-06
 * parse intro files

## 2023-06-04
 * improve upload check

## 2023-05-12
 * bugfix puppet without picture

## 2023-05-09
 * bugfix empty puppet

## 2023-05-07
 * fix availability.html with missing roles per scene
 * remove implicit table for the show

## 2023-05-06
 * extend availability.html with missing roles

## 2023-05-01
 * support local availability.ini to fix spelling of actors
 * exclude more special characters

## 2023-04-15
 * bugfix hands in people export
 * support for hands = "None"
 * option "assignment_show_all_hands"
 * add YAML config files
 * generate availability.html

## 2023-04-14
 * export people list as JSON

## 2023-04-13
 * ignore empty prop lines
 * new check for "%HND%" without stagehand
 * support role alias in header

## 2023-04-11
 * FrontProp and SecondLevelProp defaults to no hands
 * assignment detect roles without spoken lines
 * assignment skip props without hands
 * assignment export scenes as numbers
 * assignment export remove suffix on roles

## 2023-04-02
 * limit substitutions to one scene

## 2023-03-26
 * namespace ef27
 * Self-Assignment, CSV Export
 * Add puppet builders to credits

## 2022-08-05
 * role_collection

## 2022-07-11
 * Add date to highlighted scripts

## 2022-07-11
 * Support actor names in brackets

## 2022-05-06
 * Fix extra highlights in spoken lines

## 2022-05-01
 * reduce table "People_People"

## 2022-04-24
 * bugix "Todo" None can be used on all puppets.

## 2022-04-23
 * bugfix "Todo" when Voice and No-Voice in same role.

## 2022-04-18
 * bugfix "Todo" list items same name but diffrent type

## 2022-04-18
 * bugfix "Puppet costumes" when revert to none

## 2022-04-16
 * bugfix "Puppet costumes" seen.

## 2021-01-14
 * bugfix "all", new scenes had been missing

## 2021-01-13
 * bugfix "People Export", skip some hands

## 2021-01-11
 * add Report "People Export" with props for "PPS_Self_Scheldule"

## 2021-01-08
 * Fix regression with images in "clothes.pdf"

## 2021-01-07
 * add actors to "Puppet costumes"

## 2020-03-22
 * rename Clothes to Costumes, Clothing to Costume
 * Strip spaces parsing "Backdrop" tables
 * Improve Navigation

## 2020-03-21
 * Add scene header to report "People people" 
 * Add Report "Todo List"

## 2020-03-03
 * Report Conflicting Puppets, Costumes

## 2020-03-01
 * Change default names for Actor, Hands, Voice, Puppet, Clothing

## 2020-02-30
 * Skip empty lines in table "People people"

## 2020-02-29
 * Write template for props in "todo" lines at the end of each scene.
 * Enforce use use of " in spoke lines
 * Pass " in spoke lines to output
 * Bugfix empty stangehand in header with %FOG%
 * Table "People people"
 * Table "Puppet plays" columns not rotated
 * Parse backdrop table with position
 * Add default Backdrop
 * Add tables at top

## 2020-02-24
 * Bugfix in merging role definitions

## 2020-02-23
 * Make "== DIALOGUE ==" a valid option

## 2020-01-11
 * Track filename of scene, needed for highlight

