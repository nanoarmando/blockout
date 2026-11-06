## ADDED Requirements

### Requirement: Schedule a session from the task detail
The task detail SHALL show a "+ Agendar sesión" action under its blocks for every task, whatever its estimate, scheduled time or status. It SHALL replace the "+ Agendar las horas restantes" action, which SHALL no longer appear. The "Xh de Yh agendada" summary SHALL stay unchanged.

#### Scenario: Task without estimate
- **WHEN** the user opens a task without an estimate
- **THEN** the detail shows "+ Agendar sesión"

#### Scenario: Estimate already scheduled
- **WHEN** a task with estimate 2h already has 2 hours of blocks
- **THEN** the detail shows "2h de 2h agendada" and still shows "+ Agendar sesión"

### Requirement: Session length and placement
"Agendar sesión" SHALL create one block whose length is the default block length configured in settings for that task. It SHALL place the block in the first free slot of today within working hours, starting no earlier than the next quarter hour. When today has no such slot (weekend, past working hours, or fully busy), it SHALL use the first free slot of the following working days within the next two weeks. When no slot exists in that period, it SHALL show an error and create nothing.

#### Scenario: Free time today
- **WHEN** it is 10:05 on a working day, the default length is 60 minutes, and the calendar is free from 10:15 to 12:00
- **THEN** a block from 10:15 to 11:15 is created today

#### Scenario: No time left today
- **WHEN** it is 18:30 on a Friday after working hours
- **THEN** the block is created in the first free slot of Monday

#### Scenario: Nothing free in two weeks
- **WHEN** no free slot of the default length exists in the next two weeks
- **THEN** an error says no free slot was found and no block is created

### Requirement: Sessions on done tasks
"Agendar sesión" SHALL work on done tasks, and creating the session SHALL reopen the task to "Por hacer" without the "Reabierto" mark (superseded by `keep-completed-task-blocks`).

#### Scenario: Done task
- **WHEN** the user chooses "+ Agendar sesión" on a done task
- **THEN** a new block is created for it and the task becomes "Por hacer" without the "Reabierto" badge
