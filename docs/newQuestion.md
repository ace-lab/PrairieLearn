# Question format v3

A **_question_** is really a parameterized question generator that can generate random **_variants_** of itself. One question can have many variants, and a student can make one or more **_submissions_** of an answer to each variant.

A question consists of **_metadata_**, a set of HTML **_templates_**, and (optionally) a set of **_question functions_** in either Python or JavaScript.

All state of question metadata, variants, and submissions is stored in JSON format.

## Question metadata

The metadata of a question describes the question.

| Property           | Type            | Description                                                                                                                 |
| ------------------ | --------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `name`             | string          | A short unique name for the question, not visible by students. This is taken from the directory name of the question files. |
| `uuid`             | UUID            | A globally-unique identifier like `b3866207-0a3b-444e-a8c1-355739370152`.                                                   |
| `title`            | string          | A longer description of the question that is shown to the student.                                                          |
| `thumbnail`        | string          | A filename containing a thumbnail image for the question.                                                                   |
| `topic`            | string          | The course topic that the question belongs to.                                                                              |
| `secondary_topics` | list of strings | Other course topics associated with the question.                                                                           |
| `tags`             | list of strings | Course tags associated with this question.                                                                                  |
| `options`          | object          | Configuration data for this question. Overrides course-level configuration data.                                            |

## Question objects

PrairieLearn stores several types of objects in the database to keep track of a particular question variant and the student submitted answers.

| Object         | Type    | Description                                                                                                                                                    |
| -------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `options`      | object  | Union of the `course.options` and `question.options`, used to control high-level behavior like tolerances for defining a correct answer.                       |
| `variant_seed` | integer | A system-generated random value that is used to produce a question `variant`.                                                                                  |
| `variant`      | object  | All the information associated with a single parameterized version of a question. This will typically (although not necessarily) have a single correct answer. |
| `submission`   | object  | All the information associated with the submission of an answer by a student, including the grading information if the submission has been graded.             |

#### `variant` object

| Property              | Type    | Description                                                                          |
| --------------------- | ------- | ------------------------------------------------------------------------------------ |
| `variant.params`      | object  | The parameters that describe this variant of the question.                           |
| `variant.descriptors` | object  | Variables that are used to disaggregate question statistics.                         |
| `variant.true_answer` | object  | The correct answer to this variant.                                                  |
| `variant.complete`    | boolean | Whether the student has completely answered this variant (correctly or incorrectly). |

#### `submission` object

| Property                          | Type    | Description                                                                                                                                                                                                                                       |
| --------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `submission.submitted_answer`     | object  | The answer submitted by the student, parsed.                                                                                                                                                                                                      |
| `submission.raw_submitted_answer` | object  | The answer submitted by the student, exactly as submitted (not parsed).                                                                                                                                                                           |
| `submission.format_errors`        | object  | Any errors encountered during parsing.                                                                                                                                                                                                            |
| `submission.scorable`             | boolean | Whether the answer was scorable. This is normally `true`, but might be set to `false` if the answer had a format error and couldn't be scored (e.g., a non-numeric value entered for a numeric answer, or a code submission that didn't compile). |
| `submission.score_perc`           | object  | The percentage score for the submission (0 to 100).                                                                                                                                                                                               |
| `submission.feedback`             | object  | Any feedback that should be shown to the student to explain what was wrong with their answer.                                                                                                                                                     |

## Question functions

The question functions are called by PrairieLearn to generate and grade question variants.

#### `get_data()` question function

| Argument       | Intent |
| -------------- | ------ |
| `variant_seed` | In     |
| `options`      | In     |
| `variant`      | Out    |

Generates a `variant` from a `variant_seed`. The output should be deterministic functions of the inputs, so the randomness of the variant generation comes only from the `variant_seed` that is randomly generated by the main PrairieLearn system. All properties of the `variant` are optional and will be replaced by empty defaults if missing. The `variant.complete` property is ignored and always set to `false` after `get_data()` is called.

#### `grade_answer()` question function

| Argument     | Intent |
| ------------ | ------ |
| `options`    | In     |
| `variant`    | In/Out |
| `submission` | In/Out |

Grades the `submission.submitted_answer` to fill in the `submission.score` and other properties. Can optionally update the `variant` to modify the question before the student makes another submission. By modifying the `variant` a `grade_answer()` function can implement complex student interactions, such as providing interactive hints or allowing a student to submit additional information for partial credit.

## Question templates

The question templates are HTML files with placeholders for randomized parameters. Each template is rendered on the server and then combined into a webpage that is shown to the student.

| Name              | Guaranteed objects                      | Optional objects               | Required | Purpose                                            |
| ----------------- | --------------------------------------- | ------------------------------ | -------- | -------------------------------------------------- |
| `question.html`   | `options`, `params`                     | `submitted_answer`, `feedback` | Yes      | The actual question text presented to the student. |
| `submission.html` | `options`, `params`, `submitted_answer` | `feedback`                     | No       | The rendering of a student's submitted answer.     |
| `answer.html`     | `options`, `params`, `true_answer`      |                                | No       | The true answer to the question.                   |

## Subquestions

No support at present for subquestions. This will be added in a future version.

## Basic question flow

To understand how the different parts of a question work together, the flow of a simple single-shot question is given below. We generate the question variant, the student answers it, and then we grade it.

| Function          | Description                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------- |
| System            | Generate a random `variant_seed`.                                                             |
| `get_data()`      | Create a variant by generating `params` and `true_answer` from `variant_seed`.                |
| System            | Store the `variant` in the database.                                                          |
| `question.html`   | Render the variant using `params`.                                                            |
| System            | Display the question to the student.                                                          |
| Student           | Input answer and click "Submit" button, creating the `submitted_answer`.                      |
| `grade_answer()`  | Take `params`, `true_answer`, and `submitted_answer` and generate the `score` and `feedback`. |
| System            | Store the `submission` in the database.                                                       |
| `submission.html` | Render the submission using `params`, `submitted_answer`, and `feedback`.                     |
| `answer.html`     | Render the correct answer using `params` and `true_answer`.                                   |
| System            | Display the submission and answer to the student.                                             |

## Full question flow

Depending on the type of assessment (e.g., `Homework` or `Exam`) and the order that a student choosse to navigate and answer questions, the actual flow may be much more complicated than the basic flow shown above. The best way to think about the full system is to break it down into basic operations that can be composed into arbitrary workflows. These basic operations are:

| Operation             | Description                                                                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Create variant        | Create a new randomized question variant.                                                                                      |
| Display question page | Render the question templates to show a student the question variant, all previous submissions, and possibily the true answer. |
| Save answer           | Take a submitted answer from the student and save it to the database.                                                          |
| Grade answer          | Grade a saved submitted answer.                                                                                                |

The details of these basic operations are given below.

#### “Create variant” operation flow

| Function     | Description                                                                    |
| ------------ | ------------------------------------------------------------------------------ |
| System       | Generate a random `variant_seed`.                                              |
| `get_data()` | Create a variant by generating `params` and `true_answer` from `variant_seed`. |
| System       | Store the `variant` in the database.                                           |

After the variant is created it is normally displayed to the student on the question page.

#### “Display question page” operation flow

| Function          | Description                                                                                               |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| `question.html`   | Render the variant using `params`.                                                                        |
| `submission.html` | If there are submissions, then render each submission using `params`, `submitted_answer`, and `feedback`. |
| `answer.html`     | If `variant.complete` then render the true answer using `params` and `true_answer`.                       |
| System            | Display the rendered question and possibily submissions and true answer to the student.                   |

Depending on the type of assessment, the number of previous submissions, and the value of `variant.complete`, the question-display page may permit the student to do some of:

1. Save a new `submitted_answer`
2. Grade an existing saved `submitted_answer`
3. Submit and immediately grade a new `submitted_answer` (the equivalent of the two previous operations)
4. Generate a new variant of the question

#### “Save answer” operation flow

| Function         | Description                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------------- |
| Student          | Input answer and click "Submit" button, creating the `submitted_answer`.                      |
| `grade_answer()` | Take `params`, `true_answer`, and `submitted_answer` and generate the `score` and `feedback`. |
| System           | Store the `submission` in the database.                                                       |

After a submission is saved to the database the question page would normally be redisplayed to show the updated state with a saved answer.

#### “Grade answer” operation flow

| Function         | Description                                                                                   |
| ---------------- | --------------------------------------------------------------------------------------------- |
| System           | Read the `variant` and `submission` out of the database.                                      |
| `grade_answer()` | Take `params`, `true_answer`, and `submitted_answer` and generate the `score` and `feedback`. |
| System           | Update the `variant` and `submission` in the database.                                        |

After a submitted answer has been graded the question page is normally redisplayed to show the score and other information.
