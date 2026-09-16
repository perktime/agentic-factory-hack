# Intelligent Predictive Maintenance Demo Guide

This guide turns the five workshop challenges into a single, cohesive demonstration of an agent-assisted predictive maintenance workflow.

The demo follows one factory incident from machine telemetry through diagnosis, repair planning, scheduling, and parts ordering:

> Machine telemetry -> anomaly classification -> fault diagnosis -> repair plan -> maintenance schedule -> parts order

The recommended format is a **25-35 minute presentation** using resources that have been provisioned and tested in advance. The full workshop takes several hours and should not be rebuilt live during the demo.

## Demo objective

Show how specialized agents can coordinate data, tools, knowledge, and operational decisions while keeping the workflow observable and reviewable by people.

The demo should communicate three ideas:

1. Agents are most useful when they have focused responsibilities and access to trusted tools and data.
2. A multi-agent workflow can connect analytics, maintenance, workforce, and supply-chain decisions.
3. Human review, governance, and observability remain essential when AI participates in operational processes.

## Audience

This demo is suitable for:

- Developers and solution architects evaluating agentic application patterns
- Manufacturing and operations leaders exploring predictive maintenance
- Platform teams interested in Microsoft Foundry, Agent Framework, MCP, and Aspire
- Engineering teams learning how Python and .NET agents can work together

## The scenario

A tire factory receives telemetry from a production machine. One sensor reading exceeds its expected operating range.

The system must answer:

1. Is the reading anomalous, and how urgent is it?
2. What is the likely fault?
3. What work, skills, and parts are required?
4. When should maintenance take place?
5. Are the required parts available, or must they be ordered?

Five specialized agents collaborate to answer those questions:

| Agent | Responsibility | Primary output |
|---|---|---|
| Anomaly Classification | Evaluate telemetry and classify severity | Anomaly assessment |
| Fault Diagnosis | Use operational context and grounded knowledge to identify likely causes | Diagnosed fault |
| Repair Planner | Convert the diagnosis into tasks, skills, technicians, and parts | Work order |
| Maintenance Scheduler | Balance risk, technician availability, and production impact | Maintenance schedule |
| Parts Ordering | Check inventory and supplier constraints | Parts reservation or order |

## Technology story

The demo intentionally combines multiple technologies to represent a realistic enterprise environment:

| Technology | Role in the demo |
|---|---|
| Microsoft Foundry | Hosts and manages selected agents and model deployments |
| Microsoft Agent Framework | Defines agents and orchestrates the workflow |
| Model Context Protocol (MCP) | Gives agents consistent access to remote tools |
| API Management | Governs selected tool and agent endpoints |
| Foundry IQ and AI Search | Ground diagnosis in factory knowledge |
| Cosmos DB | Stores operational data, work orders, memory, schedules, and parts orders |
| GitHub Copilot | Helps build the .NET Repair Planner Agent |
| Application Insights | Captures traces, model calls, latency, and failures |
| .NET Aspire | Starts the polyglot application and provides local observability |

See the [workshop overview](./README.md) for the complete architecture and learning objectives.

## Recommended golden path

Use one machine and one fault for the entire presentation. Do not switch scenarios between challenges.

A useful golden path is:

- **Machine:** Tire Building Machine B1 (`machine-002`)
- **Telemetry:** Drum vibration above the warning threshold
- **Fault:** `building_drum_vibration`
- **Required skill examples:** Vibration analysis, bearing replacement, and alignment
- **Required part example:** `TBM-BRG-6220`

This path is easy to explain visually: abnormal vibration can indicate a mechanical issue, which leads naturally to inspection, technician selection, maintenance scheduling, and a bearing inventory check.

## Demo agenda

| Segment | Target time | Demonstration |
|---|---:|---|
| Business problem and architecture | 3 minutes | Explain the factory scenario and five agent roles |
| Challenge 0: Data foundation | 2 minutes | Show the pre-provisioned Azure resources and sample operational data |
| Challenge 1: Detect and diagnose | 5 minutes | Classify anomalous telemetry and ground a diagnosis through tools and knowledge |
| Challenge 2: Plan the repair | 5 minutes | Show Copilot-assisted development and generate a structured work order |
| Challenge 3: Schedule and order | 5 minutes | Create a maintenance schedule, evaluate parts, and inspect memory or traces |
| Challenge 4: End-to-end workflow | 10 minutes | Trigger the complete workflow in the UI and inspect execution in Aspire |
| Summary | 3 minutes | Reinforce governance, human review, and production considerations |

## Before the demo

### Provision and validate Azure resources

Complete [Challenge 0](./challenge-0/README.md) before the presentation.

Confirm that:

- The Foundry project and required model deployments are available.
- API Management endpoints respond successfully.
- Cosmos DB containers contain the sample data.
- The knowledge source and knowledge base are ready.
- Application Insights receives telemetry.
- Required role assignments have propagated.

Do not provision infrastructure during the live presentation. Deployment and role propagation can take several minutes and introduce avoidable risk.

### Validate each agent independently

Run each stage before testing the combined workflow:

1. Complete the anomaly and diagnosis checks from [Challenge 1](./challenge-1/README.md).
2. Generate a work order with the Repair Planner from [Challenge 2](./challenge-2/README.md).
3. Run both operational agents from [Challenge 3](./challenge-3/README.md).
4. Start and exercise the workflow from [Challenge 4](./challenge-4/README.md).

Do not use the end-to-end workflow as the first validation of an agent.

### Prepare the demo state

- Use a dedicated, non-production Azure environment.
- Seed deterministic sample data.
- Select one known telemetry payload for the golden path.
- Remove work orders, schedules, and parts orders left by earlier rehearsals, or use unique demo IDs.
- Confirm that the required parts and technicians produce the intended scenario.
- Confirm that the model and agent identifiers match the current Foundry resources.
- Test the complete workflow from the same machine and network used for the presentation.

### Prepare fallbacks

Keep the following available in case a cloud operation is delayed:

- Screenshot of a successful anomaly classification
- Screenshot of the grounded fault diagnosis and citations
- Example generated work order
- Example maintenance schedule and parts order
- Screenshot of an Application Insights trace
- Short recording of the complete Aspire workflow

Fallback material should show a previously completed run of the same golden-path incident.

## Presenter runbook

### 1. Introduce the business problem

Open the [workshop overview](./README.md) and show the maintenance scenario.

Suggested narration:

> Unplanned downtime affects factory throughput, quality, and cost. Diagnosing a machine problem is only the first step. A useful solution must also determine the repair, find qualified people, coordinate production downtime, and ensure that parts are available.

Explain that the agents assist technicians and planners. They do not directly control production machinery or approve safety-critical work.

### 2. Show the data foundation

Use [Challenge 0](./challenge-0/README.md) to explain the pre-provisioned environment.

Show only a few representative resources:

- One machine document
- One telemetry document
- One threshold document
- One technician or parts inventory document
- One maintenance knowledge article

Avoid spending time navigating every resource. The purpose of this segment is to establish that agent decisions use operational data rather than information embedded entirely in prompts.

Suggested transition:

> Now that the agents have access to factory context, we can submit a new machine reading.

### 3. Detect the anomaly

Follow the Anomaly Classification portion of [Challenge 1](./challenge-1/README.md).

Submit the prepared drum-vibration telemetry and highlight:

- The observed value
- The expected threshold
- The resulting severity and priority
- The MCP tool call used to retrieve machine or threshold data

Suggested narration:

> The model is responsible for interpretation, but the measurements and limits come from governed operational tools.

### 4. Diagnose the fault

Continue with the Fault Diagnosis portion of [Challenge 1](./challenge-1/README.md).

Show:

- The anomaly passed from the first agent
- Retrieval from the factory knowledge base
- The likely root cause
- Recommended verification steps
- Grounding references or citations

Suggested narration:

> The diagnosis is grounded in maintenance knowledge rather than relying only on the model's general training.

### 5. Build and run the Repair Planner

Open [Challenge 2](./challenge-2/README.md).

Briefly show the custom `agentplanning` Copilot agent and explain that it contains the workshop's Foundry Agents SDK and domain guidance.

Do not generate the entire application live. Instead:

1. Show one focused Copilot interaction or a small refinement.
2. Show the resulting .NET structure.
3. Run the Repair Planner with the diagnosed fault.
4. Inspect the generated work order.

Highlight:

- Repair tasks
- Required skills
- Candidate technicians
- Required parts
- Estimated effort
- Persistence to Cosmos DB

Suggested narration:

> Copilot helps build the agent, while the runtime agent uses operational data to create the maintenance plan.

### 6. Schedule maintenance and evaluate parts

Use [Challenge 3](./challenge-3/README.md).

Run the Maintenance Scheduler and show how it considers:

- Fault priority and risk
- Machine history
- Production impact
- Available maintenance windows
- Technician availability

Then run the Parts Ordering Agent and show:

- Current inventory
- Required quantity
- Supplier and lead-time considerations
- Reservation or purchase recommendation

If time permits, run one agent twice for the same machine or work order and show how stored conversation history supplies context.

Open one trace in Application Insights and point out:

- Agent execution duration
- Tool and database operations
- Model call latency
- Errors or retries, if present

Suggested transition:

> We have now tested each capability. The final step is to operate them as one observable workflow.

### 7. Trigger the complete Aspire workflow

Follow [Challenge 4](./challenge-4/README.md) to start Aspire and open the frontend.

Trigger the prepared anomaly and watch each workflow stage:

1. Anomaly Classification
2. Fault Diagnosis
3. Repair Planner
4. Maintenance Scheduler
5. Parts Ordering

Use the application UI for the business story and the Aspire dashboard for the engineering story.

In the application UI, emphasize the progression and resulting maintenance recommendation. In Aspire, show:

- Service health
- Logs from the Python and .NET processes
- Workflow execution
- Trace correlation across services

Do not spend the entire demo reading model responses. Focus on handoffs, tool use, decisions, and observability.

### 8. Close with governance and human review

Suggested narration:

> The result is not an autonomous command to repair the machine. It is an evidence-backed proposal that a technician or maintenance planner can review, adjust, and approve.

Discuss production requirements:

- Authentication and authorization
- Human approval for work orders and purchases
- Tool allow-lists and least-privilege identities
- Input and output validation
- Audit history and trace retention
- Evaluation of quality, safety, latency, and cost
- Failure handling and deterministic business rules
- Network isolation and private endpoints

## Demo environment and networking

Aspire is used as a development and demonstration host. Its dashboard and generated service endpoints should not be treated as public production endpoints.

For a remote demo:

- Prefer authenticated VS Code or Codespaces port forwarding.
- Alternatively, expose only the frontend through a reverse proxy with HTTPS.
- Keep the Aspire dashboard, APIs, telemetry endpoints, and databases private.
- Use a fixed frontend port rather than relying on an Aspire-generated port.
- Bind the frontend to the required network interface only when remote access is necessary.
- Never expose secrets, `.env` files, connection strings, or access tokens.

If a Network Security Group rule is temporarily opened for the presentation, restrict it to the presenter's public IP whenever possible and remove it immediately afterward.

## Failure handling during the presentation

| Failure | Presenter response |
|---|---|
| Model response is slow | Explain that the request is executing remotely, then show the trace or prepared output |
| Foundry agent is unavailable | Use the saved response and continue with the same diagnosed fault |
| MCP endpoint fails | Show the expected tool result and explain the governed integration boundary |
| Cosmos DB contains stale data | Use a unique incident or work-order ID |
| Trace has not appeared | Explain telemetry batching and show a trace from the rehearsal |
| Aspire resource fails | Show its logs, then use the recorded end-to-end run |
| Public frontend is unreachable | Use local or authenticated port forwarding rather than changing multiple firewall settings live |

The goal is to preserve the story. Do not spend most of the presentation troubleshooting infrastructure.

## Security and responsible AI notes

This demo uses fictional factory data and must remain separated from production systems.

The demonstration should not imply that:

- A language model directly controls machinery.
- Generated diagnoses replace qualified technicians.
- Work orders or purchases are approved without human review.
- Model reasoning is guaranteed to be correct.
- Development-time public endpoints are a production deployment pattern.

Present model outputs as recommendations supported by tools, knowledge, rules, and traceable evidence.

## Post-demo cleanup

After the presentation:

1. Restrict or remove temporary public Network Security Group rules.
2. Stop Aspire and development servers.
3. Remove temporary public port-forwarding visibility.
4. Review generated work orders, schedules, and parts orders.
5. Revoke temporary credentials or role assignments.
6. Confirm that no secrets were captured in recordings, screenshots, logs, or shell history.
7. Stop or delete Azure resources that are no longer needed to control cost.

## Success criteria

The demo is successful when the audience can clearly explain:

- Why each agent has a separate responsibility
- How tools and operational data ground agent behavior
- How the output of one agent becomes the input to another
- How the system crosses Python, .NET, local, and hosted boundaries
- How logs and traces make the workflow observable
- Where people approve or override recommendations
- What would need to change before using the pattern in production

The most important result is not that five agents execute. It is that the workflow produces a coherent, reviewable maintenance recommendation from a concrete factory signal.
