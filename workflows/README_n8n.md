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
    +-- websearchstack.json             (main workflow)
    +-- export-workflows.sh             (helper script to export workflows)
<!--    +-- scoring.json                    (optional: LLM scoring workflow)
    +-- export-workflows.sh             (script that pulls workflows from n8n)
-->

### Exporting workflows from n8n


Version control tracks individual workflows, not the entire n8n
instance. To export one workflow, you need its ID.

#### Step 1: Get the workflow ID from the browser

Open the workflow in n8n and look at the URL:

    http://127.0.0.1:5678/workflow/AbCdEf123456XyZ

The ID is the segment after `/workflow/`. In this example:
`AbCdEf123456XyZ`.

#### Step 2: Create the export folder inside the container (***first time only***)

Create a folder inside n8n node ***if it is the first time*** exporting
for control version.
For instance a folder called `workflows` since that folder does not exist by default:

    docker exec n8n mkdir -p /home/node/workflows

#### Step 3: Export the specific workflow

Workflows live inside the n8n container. To pull them out for version
control:

    docker exec n8n n8n export:workflow --id=AbCdEf123456XyZ --output=/home/node/workflows/websearchstack.json --pretty

- `--id` selects the specific workflow.
- `--output` specifies the file path inside the container.
- `--pretty` formats the JSON for readable diffs.
- `AbCdEf123456XyZ` is an example of your workflow ID
- `websearchstack.json` is the name of the main workflow

#### Step 4: Copy the file to the host repository

    docker cp n8n:/home/node/workflows/websearchstack.json /home/user/gitpath/repopath/workflows/

#### Step 5: Commit

    cd /home/user/gitpath/repopath/
    git add workflows/websearchstack.json
    git commit -m "Update workflow"

---

### About Workflow IDs

The workflow ID is an internal handle assigned by n8n. It is not the
same as the workflow name shown in the browser.

- When you create a workflow in the GUI, n8n assigns an ID
  automatically.
- When you import a workflow from a JSON file (for example, after
  cloning the repository on a new machine), n8n assigns a new ID.
  The ID stored in the file is not preserved.
- This means the export command with `--id` only works on the machine
  where that specific ID currently exists. On a fresh clone, import
  the JSON through the GUI, then look up the new ID if you want to
  export it again.

### What Not to Use for Version Control

Do not use `--backup` for this repository. That flag exports all
workflows in the n8n instance, including experimental ones created in
the GUI. The repository is meant to track only the workflows that
belong to this project.

### Restoring a Workflow from the Repository

On a new n8n instance:

1. Open n8n in the browser.
2. Go to Workflows.
3. Use the menu in the top-right corner and select Import from File.
4. Select the JSON file from the `workflows/` folder.
5. n8n creates a new workflow with a new ID. The name is preserved
   from the file.
6. Recreate any credentials referenced by the workflow and re-link
   them in the affected nodes.

## 5. Optional Helper Script

If you export the same workflow repeatedly, open `export-workflows.sh`
and edit `WORKFLOW_ID`, `WORKFLOW_NAME` and `HOST_REPO` accordingly.

Run it with `./export-workflows.sh` whenever you want to refresh the
tracked file. 

## 6. Notes on credentials inside workflows

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
