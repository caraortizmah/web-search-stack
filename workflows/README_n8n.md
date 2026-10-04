# n8n Workflows

This folder contains the exported workflow definitions used by the job
search pipeline. Each file is a JSON document produced by n8n's export
command.

---

## 1. Workflow Schematic

The main workflow follows this general sequence:

```
    Timer
      |
      +--------+---------+------(...)-----------+---(...)-----
      |        |         |                      |
      v                                         v
    HTTP POST     (...)                       HTTP GET      (...)
  Request 1 (source 1)... request N    Request 1 (source 2)... request M
      |                                         |
    (Via Flaresolverr)                          |
      |                                         |
   Object parser to json                        |
      |                                         |
   Split data array (source 1)          Split data array (source 2) 
      |                                         |
      |        |  (...)  |                      |    |  (...) |
      +--------+--(...)--+                      +----+--------+
               |                                     |
               v                                     v
            Merge (Source 1)                     Merge (Source 2)
               |                                     |
            Remove duplicates                     Remove duplicates
               |                                     |
          Normalization (Code)                 Normalization (Code)
               |                                     |
               v                                     v
               +------------------+------------------+
                                  |
                                  v
                                Merge
                                  |
                                  v
                           Remove Duplicates
                                  |
                                  v
                           Update MongoDB

```

### Step-by-step

1. Timer
   Triggers the workflow on a schedule, for example once per day.

2. HTTP Request (per source), for instance shop products or job board.
   One node per task (e.g. job board) or API. Each node sends its 
   own query parameters (keywords, location, posting age). 
   If a source is protected by a JavaScript challenge, a POST request 
   to the FlareSolverr container is used instead of a direct request.

3. Object parser to json (case of POST request)
   The data is wrapped in HTML. FlareSolverr returns the raw page, 
   and thw webpage (source 1) renders its JSON inside 
   an HTML`<pre>` tag. JSON string is extracted from the HTML before 
   parsing it.

4. Split data array
   Data is formatted to better manilupation in the following steps.   

5. Merge
   Combines the JSON outputs from all requests into a single stream.

5. Remove Duplicates
   Eliminates repeated entries within the merged stream, using a
   stable identifier.

6. Normalization (Code node) - let's continue with job board example
   Converts the raw response from each source into a common schema with
   consistent field names: `title`, `company`, `location`, `url`,
   `description`, `source`, and a deterministic `jobHash`.

7. Merge
   Combines the normalized outputs from all sources into a single
   stream.

8. Remove Duplicates (again)
   Eliminates repeated entries within the merged stream, using a
   stable identifier.

9. Update MongoDB
   Writes each item to the database. The operation uses a ***hash***
   as the update key with upsert enabled.
   In the case of job example, a job is inserted the first time 
   it is seen and only updated on subsequent runs.

---

## 2. Why a deterministic hash is used

The same, e,g., job can appear on multiple boards with slightly 
different titles or formatting. To detect that two entries refer to the 
same position, the workflow computes a hash from a normalized 
combination of title and company. 
This hash is stored in the `jobHash` field and used as the update key.

Because the hash is deterministic, the same input always produces the
same output. This is what makes the upsert behavior work: the second
time a job appears, MongoDB recognizes it and updates the existing
document instead of creating a duplicate.

---

## 3. Recommended repository layout for workflows

    workflows/
    |
    +-- README_n8n.md                   (this file)
    +-- job-search-pipeline.json        (main workflow)
<!--    +-- scoring.json                    (optional: LLM scoring workflow)
    +-- export-workflows.sh             (script that pulls workflows from n8n)
-->

### Exporting workflows from n8n

Workflows live inside the n8n container. To pull them out for version
control:

    docker exec n8n n8n export:workflow --backup --output=/home/node/workflows/ --separate
    docker cp n8n:/home/node/workflows/. ./workflows/

The `--separate` flag writes each workflow to its own JSON file, which
produces cleaner diffs when committed to git.

---

## 4. Notes on credentials inside workflows

Exported workflow JSON files do not contain the actual credential
values, but they do reference credential IDs. This means:

- The files are safe to commit.
- A person restoring the workflows on a different n8n instance will
  need to recreate the credentials manually and re-link them in the
  affected nodes.


***NOTE: Do not paste API keys or passwords directly into node parameters.***
Always use n8n's credential system, so that the values stay out of the
exported files.

---

## 5. Adding a New Source

To add another job board:

1. Duplicate an existing HTTP Request node and adjust its URL and
   parameters.
2. Add a Code node after it that maps the new source's field names to
   the common schema.
3. Connect the Code node to the same Merge node.
4. Re-export the workflow and commit the updated JSON file.

Keep one HTTP Request node per source. Do not combine multiple
unrelated APIs into a single node, because each source has its own
response format and error behavior.
