## Purpose

Lets the user capture, find and maintain tasks and projects in Blockout, with native fields for urgency, estimate and origin instead of conventions in the title.

## ADDED Requirements

### Requirement: Task fields
Each task SHALL have a title, an optional project, an urgency level (none, low `!`, medium `!!`, high `!!!`), an optional estimate in hours, an optional due date, a status (por hacer, en curso, esperando, hecha), free-text notes, an optional source label and an optional external reference made of a label, an identifier and a URL. The title MUST NOT need prefixes or suffixes to express any of these fields.

#### Scenario: Task shown with its fields
- **WHEN** a task has project "Acme", urgency medium, estimate 1h, source "Odoo" and external reference "Odoo #9975"
- **THEN** its list row shows the title unchanged, a Acme project badge in the project color, a medium urgency indicator, "1h", and "Odoo #9975" as a link to the reference URL

#### Scenario: Task without optional fields
- **WHEN** a task has only a title
- **THEN** its row shows the title and no empty badges or placeholders

### Requirement: Projects
Projects SHALL have a unique name (case-insensitive) and a color. The sidebar SHALL list the five projects with the most open tasks, each with its open-task count, followed by a "Ver más" control that reveals the rest and turns into "Ver menos".

#### Scenario: More than five projects
- **WHEN** there are seven projects with open tasks
- **THEN** the sidebar shows five of them and "Ver más (2)"; activating it shows all seven and "Ver menos"

#### Scenario: Duplicate project name
- **WHEN** the user creates a project named "acme" while "Acme" exists
- **THEN** no new project is created and the existing one is used

### Requirement: Create and edit projects
A "+" button next to the "Proyectos" heading SHALL open a project sheet to create a project; right-clicking a project in the sidebar SHALL offer "Editar…", which opens the same sheet for that project, while a plain click keeps filtering the list by the project. The sheet SHALL let the user set the name and pick one of the eight palette colors, with "Cancelar" and "Guardar". "Guardar" SHALL be disabled while the name is empty, and a name already used by another project (case-insensitive) SHALL be rejected with a message, keeping the sheet open. Changes SHALL show at once wherever the project appears. The sidebar SHALL NOT contain a free-text field for new projects.

#### Scenario: Create from the sidebar
- **WHEN** the user clicks "+", types "Hooli", picks the third color and saves
- **THEN** the project "Hooli" appears in the sidebar with that color

#### Scenario: Rename and recolor
- **WHEN** the user right-clicks "Acme", chooses "Editar…", renames it to "Acme Labs" and picks another color
- **THEN** the sidebar, task badges and calendar blocks show the new name and color

#### Scenario: Name taken
- **WHEN** the user renames a project to "northwind" while "Northwind" exists
- **THEN** the sheet shows that the name is already in use and nothing changes

### Requirement: Task list groups
The task list SHALL show open tasks in two groups: "Sin agendar" (no block today or later) and "Agendadas" (at least one block today or later, showing the next block's day and time). Completed tasks SHALL NOT appear in either group; they are hidden unless the user shows them (see "Show completed tasks").

#### Scenario: Task whose only block is in the past
- **WHEN** an open task's only block ended yesterday
- **THEN** the task appears in "Sin agendar"

#### Scenario: Completing a task
- **WHEN** the user activates the completion control of a task
- **THEN** the task status becomes "hecha" and it leaves the list

### Requirement: Sidebar filters
The sidebar SHALL offer the filters Todas, Hoy (a block today; the due date does not count), Sin agendar, Agendadas, Vencidas (open and past due date) and Completadas (done tasks only), each with its count, plus one filter per project and one per source label. Selecting a filter SHALL restrict the task list to matching tasks.

#### Scenario: Overdue filter
- **WHEN** an open task was due yesterday and the user selects "Vencidas"
- **THEN** the list shows that task with its due date highlighted as overdue

### Requirement: Filter-and-create input
A single input above the list SHALL filter the visible tasks while the user types, matching case-insensitively against title, project and source, and show the match count. Pressing Enter with non-empty text SHALL create a task from the text and clear the input.

#### Scenario: Live filtering
- **WHEN** the user types "swiss"
- **THEN** only tasks whose title, project or source contains "swiss" are shown, with the count of matches

#### Scenario: Create with Enter
- **WHEN** the user types "Revisar sync 2h !!" and presses Enter
- **THEN** a task "Revisar sync" is created in "Sin agendar" with estimate 2h and medium urgency, and the input is cleared

#### Scenario: Empty input
- **WHEN** the input is empty or only spaces and the user presses Enter
- **THEN** nothing is created

### Requirement: Project detection on create
When creating a task from the input, if the text contains the name of an existing project as a whole word or phrase (case-insensitive), the task SHALL be assigned to that project and the title SHALL keep the text as typed. When several projects match, the longest name SHALL win. While typing, the input SHALL show which project would be assigned.

#### Scenario: Lower-case project name
- **WHEN** the user creates "Revisar sync de acme" and the project "Acme" exists
- **THEN** the task belongs to Acme and its title is "Revisar sync de acme"

#### Scenario: Partial word does not match
- **WHEN** the user creates "Revisar rutas" and the project "Ruta" exists
- **THEN** the task has no project

### Requirement: Task detail
Opening a task SHALL show its title, project, external reference link, status selector, urgency selector, estimate, due date, origin, its blocks with day, time range and destination calendar, a "+ Agendar las horas restantes" action when the estimate exceeds the scheduled time, and editable notes. Changes SHALL be saved without an explicit save action.

#### Scenario: Remaining hours
- **WHEN** a task with estimate 3h has one 1-hour block
- **THEN** the detail shows "1h de 3h agendada" and the action to schedule the remaining 2h

### Requirement: Task context menu
Right-clicking a task row in the list SHALL open a context menu with "Abrir", which opens the task detail; "Urgencia", a submenu with Ninguna, `!`, `!!` and `!!!` marking the current level; and "Eliminar…". Changing the urgency from the menu SHALL apply at once.

#### Scenario: Change urgency from the list
- **WHEN** the user right-clicks a task with no urgency and chooses Urgencia › `!!!`
- **THEN** the task shows the high urgency indicator without opening its detail

#### Scenario: Open from the menu
- **WHEN** the user chooses "Abrir"
- **THEN** the task detail opens for that task

### Requirement: Delete a task
"Eliminar…" SHALL ask for confirmation, naming the task and how many blocks will be removed, and warning that it cannot be undone. Confirming SHALL delete the task, all its blocks (past and future, including drafts) with their calendar events, and its time entries; a running timer for the task SHALL stop. Cancelling SHALL change nothing. If a calendar event cannot be deleted, the task SHALL be kept and the user SHALL see the reason.

#### Scenario: Delete a scheduled task
- **WHEN** the user deletes a task with one past block and one future block and confirms
- **THEN** the task leaves the list and both blocks and their events disappear from the calendar

#### Scenario: Cancel deletion
- **WHEN** the user chooses "Eliminar…" and then "Cancelar"
- **THEN** the task and its blocks remain unchanged

### Requirement: Show completed tasks
A toggle icon next to the "Buscar o crear tarea" label SHALL show or hide completed tasks in the list. While shown, they SHALL appear after the other groups in a "Completadas" group, newest first, with a checked completion control; unchecking it SHALL reopen the task as "Por hacer". The toggle state SHALL persist across restarts. Selecting the "Completadas" sidebar filter SHALL show only completed tasks regardless of the toggle. Completed tasks SHALL keep being excluded from the other filters' counts.

#### Scenario: Show completed
- **WHEN** the user activates the toggle
- **THEN** a "Completadas" group with the completed tasks appears below "Agendadas"

#### Scenario: Reopen a completed task
- **WHEN** the user unchecks a task in "Completadas"
- **THEN** the task becomes "Por hacer" and moves back to its open group

#### Scenario: Completadas filter
- **WHEN** the user selects "Completadas" in the sidebar with the toggle off
- **THEN** the list shows only the completed tasks
