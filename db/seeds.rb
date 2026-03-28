# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Seed compliance templates
ComplianceTemplate.seed_templates!

# --- Demo Data (development only) ---
return unless Rails.env.development?

# Skip if demo org already exists
if Organization.exists?(slug: "acme-automotive")
  puts "Demo data already exists (acme-automotive organization found). Skipping."
  return
end

puts "Creating demo data..."

# --- Organization & Users ---
demo_org = Organization.create!(
  name: "ACME Automotive",
  slug: "acme-automotive",
  settings: { industry: "automotive", compliance: "iso_26262" }
)

admin = User.create!(
  email: "admin@acme-automotive.dev",
  password: "password123",
  first_name: "Sarah",
  last_name: "Chen"
)

pm = User.create!(
  email: "pm@acme-automotive.dev",
  password: "password123",
  first_name: "Marcus",
  last_name: "Weber"
)

engineer = User.create!(
  email: "engineer@acme-automotive.dev",
  password: "password123",
  first_name: "Priya",
  last_name: "Patel"
)

reviewer_user = User.create!(
  email: "reviewer@acme-automotive.dev",
  password: "password123",
  first_name: "James",
  last_name: "Tanaka"
)

viewer_user = User.create!(
  email: "viewer@acme-automotive.dev",
  password: "password123",
  first_name: "Elena",
  last_name: "Kowalski"
)

Membership.create!(user: admin, organization: demo_org, role: :admin)
Membership.create!(user: pm, organization: demo_org, role: :project_manager)
Membership.create!(user: engineer, organization: demo_org, role: :author)
Membership.create!(user: reviewer_user, organization: demo_org, role: :reviewer)
Membership.create!(user: viewer_user, organization: demo_org, role: :viewer)

puts "  Created organization: #{demo_org.name} with 5 users"

# --- ISO 26262 Project ---
iso_template = ComplianceTemplate.find_by!(name: "ISO 26262 — Functional Safety")

iso_project = Project.create!(
  organization: demo_org,
  name: "Battery Management System (BMS)",
  description: "ISO 26262 ASIL-D battery management system for next-generation EV platform. Covers cell balancing, thermal management, state-of-charge estimation, and fault detection with functional safety requirements from hazard analysis through system verification.",
  prefix: "BMS",
  status: :active,
  attribute_schema: []
)

module_map = iso_template.apply_to_project!(iso_project)

puts "  Created ISO 26262 project: #{iso_project.name} with #{iso_project.requirement_modules.count} modules"

# Helper to create requirements in a section
def create_req(project:, section:, user:, title:, body:, type: :functional, status: :draft, priority: :must_have, asil: :qm, custom: {})
  Requirement.create!(
    project: project,
    section: section,
    created_by: user,
    title: title,
    body: body,
    requirement_type: type,
    status: status,
    priority: priority,
    asil_level: asil,
    custom_attributes: custom
  )
end

# --- System Requirements ---
sys_mod = module_map["sys_req"]
sg_section = sys_mod.sections.find_by!(name: "Safety Goals")
fsr_section = sys_mod.sections.find_by!(name: "Functional Safety Requirements")
tsr_section = sys_mod.sections.find_by!(name: "Technical Safety Requirements")

sg1 = create_req(
  project: iso_project, section: sg_section, user: admin,
  title: "Prevention of thermal runaway propagation",
  body: "The BMS shall prevent thermal runaway propagation from a single cell to adjacent cells within the battery pack under all operating conditions.",
  type: :safety, status: :approved, priority: :must_have, asil: :asil_d,
  custom: { "Safety Goal" => "SG-01: No thermal runaway propagation", "ASIL Allocation" => "ASIL-D", "Compliance Reference" => "ISO 26262-3:2018 Clause 7" }
)

sg2 = create_req(
  project: iso_project, section: sg_section, user: admin,
  title: "Prevention of overcharge beyond safe limits",
  body: "The BMS shall prevent cell voltage from exceeding 4.25V under all charging conditions, including fast charge, regenerative braking, and external charger faults.",
  type: :safety, status: :approved, priority: :must_have, asil: :asil_c,
  custom: { "Safety Goal" => "SG-02: No overcharge beyond limits", "ASIL Allocation" => "ASIL-C", "Compliance Reference" => "ISO 26262-3:2018 Clause 7" }
)

sg3 = create_req(
  project: iso_project, section: sg_section, user: admin,
  title: "Accurate state-of-charge reporting to vehicle controller",
  body: "The BMS shall report state-of-charge (SoC) to the vehicle controller with an accuracy of +/-3% under normal operating conditions (-20C to +60C ambient temperature range).",
  type: :safety, status: :approved, priority: :must_have, asil: :asil_b,
  custom: { "Safety Goal" => "SG-03: Accurate SoC reporting", "ASIL Allocation" => "ASIL-B", "Compliance Reference" => "ISO 26262-3:2018 Clause 7" }
)

fsr1 = create_req(
  project: iso_project, section: fsr_section, user: pm,
  title: "Cell temperature monitoring with redundant sensors",
  body: "The BMS shall monitor individual cell temperatures using dual redundant NTC thermistors per cell group, with a measurement range of -40C to +85C and a resolution of 0.5C.",
  type: :functional, status: :approved, priority: :must_have, asil: :asil_d,
  custom: { "Safety Goal" => "SG-01", "Verification Method" => "Testing" }
)

fsr2 = create_req(
  project: iso_project, section: fsr_section, user: pm,
  title: "Overvoltage protection circuit activation",
  body: "The BMS shall activate the overvoltage protection circuit within 10ms of detecting a cell voltage exceeding 4.20V, disconnecting the charging path via the main contactor.",
  type: :functional, status: :approved, priority: :must_have, asil: :asil_c,
  custom: { "Safety Goal" => "SG-02", "Verification Method" => "Testing" }
)

fsr3 = create_req(
  project: iso_project, section: fsr_section, user: pm,
  title: "SoC estimation using dual algorithm approach",
  body: "The BMS shall estimate state-of-charge using both coulomb counting and open-circuit voltage lookup methods, selecting the result with lowest estimated uncertainty.",
  type: :functional, status: :in_review, priority: :must_have, asil: :asil_b,
  custom: { "Safety Goal" => "SG-03", "Verification Method" => "Analysis" }
)

fsr4 = create_req(
  project: iso_project, section: fsr_section, user: engineer,
  title: "Cell balancing during charging",
  body: "The BMS shall perform passive cell balancing during charging when the voltage difference between any two cells in a module exceeds 20mV, with a balancing current of 50mA +/-10%.",
  type: :functional, status: :draft, priority: :should_have, asil: :qm,
  custom: { "Verification Method" => "Testing" }
)

tsr1 = create_req(
  project: iso_project, section: tsr_section, user: pm,
  title: "Thermal management shutdown threshold",
  body: "The BMS shall initiate an emergency shutdown sequence when any cell temperature exceeds 60C, opening main contactors within 50ms and activating the coolant pump to maximum flow rate.",
  type: :safety, status: :approved, priority: :must_have, asil: :asil_d,
  custom: { "Safety Goal" => "SG-01", "Verification Method" => "Testing", "Compliance Reference" => "ISO 26262-4:2018 Clause 6" }
)

tsr2 = create_req(
  project: iso_project, section: tsr_section, user: pm,
  title: "Diagnostic fault code reporting",
  body: "The BMS shall report standardized diagnostic trouble codes (DTCs) via CAN bus UDS protocol for all safety-relevant faults within 100ms of fault detection.",
  type: :interface, status: :draft, priority: :must_have, asil: :asil_b,
  custom: { "Verification Method" => "Testing", "Compliance Reference" => "ISO 26262-4:2018 Clause 7" }
)

# --- Software Requirements ---
sw_mod = module_map["sw_req"]
sw_safety_section = sw_mod.sections.find_by!(name: "Software Safety Requirements")
sw_func_section = sw_mod.sections.find_by!(name: "Software Functional Requirements")
sw_iface_section = sw_mod.sections.find_by!(name: "Software Interface Requirements")
sw_nfr_section = sw_mod.sections.find_by!(name: "Software Non-Functional Requirements")

swr1 = create_req(
  project: iso_project, section: sw_safety_section, user: engineer,
  title: "Temperature sensor plausibility check",
  body: "The BMS software shall perform a plausibility check on redundant temperature sensor readings every 100ms. If the difference between redundant sensors exceeds 5C for more than 500ms, the software shall flag a sensor fault and use the higher reading for safety decisions.",
  type: :safety, status: :approved, priority: :must_have, asil: :asil_d,
  custom: { "Safety Goal" => "SG-01", "Verification Method" => "Testing" }
)

swr2 = create_req(
  project: iso_project, section: sw_safety_section, user: engineer,
  title: "Voltage monitoring watchdog",
  body: "The BMS software shall implement an independent voltage monitoring watchdog that triggers an emergency shutdown if the primary voltage monitoring task fails to execute within its 100ms deadline for 3 consecutive periods.",
  type: :safety, status: :approved, priority: :must_have, asil: :asil_c,
  custom: { "Safety Goal" => "SG-02", "Verification Method" => "Analysis" }
)

swr3 = create_req(
  project: iso_project, section: sw_func_section, user: engineer,
  title: "Coulomb counting integration",
  body: "The BMS software shall integrate current measurements using trapezoidal integration at a rate of 10Hz with a minimum current resolution of 10mA, accumulating charge and discharge energy for SoC calculation.",
  type: :functional, status: :in_review, priority: :must_have, asil: :asil_b,
  custom: { "Safety Goal" => "SG-03", "Verification Method" => "Analysis" }
)

swr4 = create_req(
  project: iso_project, section: sw_func_section, user: engineer,
  title: "Cell balancing algorithm",
  body: "The BMS software shall implement a cell balancing algorithm that selects cells for balancing based on the deviation from the module average voltage, activating balancing FETs for cells exceeding the average by more than 10mV.",
  type: :functional, status: :draft, priority: :should_have, asil: :qm,
  custom: { "Verification Method" => "Testing" }
)

swr5 = create_req(
  project: iso_project, section: sw_iface_section, user: engineer,
  title: "CAN bus message transmission",
  body: "The BMS software shall transmit the following CAN messages at the specified rates: BMS_Status (10ms), BMS_CellVoltages (100ms), BMS_Temperatures (500ms), BMS_Faults (event-triggered, max latency 50ms).",
  type: :interface, status: :draft, priority: :must_have, asil: :asil_b,
  custom: { "Verification Method" => "Testing" }
)

swr6 = create_req(
  project: iso_project, section: sw_nfr_section, user: engineer,
  title: "Worst-case execution time constraint",
  body: "The BMS software safety-critical tasks shall complete within 80% of their allocated worst-case execution time (WCET) on the target microcontroller to provide sufficient margin for interrupt handling and background tasks.",
  type: :non_functional, status: :draft, priority: :must_have, asil: :asil_d,
  custom: { "Verification Method" => "Analysis", "Compliance Reference" => "ISO 26262-6:2018 Clause 8" }
)

# --- Software Architecture ---
arch_mod = module_map["sw_arch"]
arch_comp_section = arch_mod.sections.find_by!(name: "Architectural Components")
safety_mech_section = arch_mod.sections.find_by!(name: "Safety Mechanisms")
iface_def_section = arch_mod.sections.find_by!(name: "Interface Definitions")

arch1 = create_req(
  project: iso_project, section: arch_comp_section, user: engineer,
  title: "Temperature monitoring component",
  body: "The Temperature Monitoring Component shall provide calibrated temperature readings from all cell groups, implement sensor plausibility checks, and raise temperature fault events to the Safety Manager.",
  type: :functional, status: :approved, priority: :must_have, asil: :asil_d,
  custom: { "Verification Method" => "Review" }
)

arch2 = create_req(
  project: iso_project, section: arch_comp_section, user: engineer,
  title: "Voltage monitoring component",
  body: "The Voltage Monitoring Component shall provide calibrated cell voltage readings at 10Hz, detect overvoltage/undervoltage conditions, and command contactor control via the Safety Manager.",
  type: :functional, status: :approved, priority: :must_have, asil: :asil_c,
  custom: { "Verification Method" => "Review" }
)

arch3 = create_req(
  project: iso_project, section: safety_mech_section, user: engineer,
  title: "Safety manager watchdog",
  body: "The Safety Manager shall implement a hardware watchdog trigger mechanism that must be serviced within 200ms. Failure to service the watchdog shall result in a hardware reset and safe-state entry.",
  type: :safety, status: :in_review, priority: :must_have, asil: :asil_d,
  custom: { "Verification Method" => "Testing" }
)

arch4 = create_req(
  project: iso_project, section: iface_def_section, user: engineer,
  title: "SPI communication with cell monitoring IC",
  body: "The BMS software shall communicate with the LTC6811 cell monitoring IC via SPI at 1MHz clock rate, using CRC-15 error detection on all data transfers.",
  type: :interface, status: :draft, priority: :must_have, asil: :asil_c,
  custom: { "Verification Method" => "Testing" }
)

# --- Unit Test Specifications ---
ut_mod = module_map["unit_test"]
ut_section = ut_mod.sections.find_by!(name: "Unit Test Cases")

ut1 = create_req(
  project: iso_project, section: ut_section, user: engineer,
  title: "Temperature plausibility check unit test",
  body: "Verify that the temperature plausibility check correctly identifies sensor faults when redundant sensors differ by more than 5C for 500ms, and selects the higher reading.",
  type: :functional, status: :draft, priority: :must_have, asil: :asil_d,
  custom: { "Verification Method" => "Testing" }
)

ut2 = create_req(
  project: iso_project, section: ut_section, user: engineer,
  title: "Coulomb counting accuracy test",
  body: "Verify that the coulomb counting integration accumulates charge within +/-0.1% of the theoretical value over a 1-hour constant-current charge cycle at 1C rate.",
  type: :functional, status: :draft, priority: :must_have, asil: :asil_b,
  custom: { "Verification Method" => "Testing" }
)

# --- Integration Test Specifications ---
it_mod = module_map["int_test"]
it_section = it_mod.sections.find_by!(name: "Integration Test Cases")

it1 = create_req(
  project: iso_project, section: it_section, user: engineer,
  title: "Temperature monitoring to safety manager integration test",
  body: "Verify that a temperature threshold exceedance detected by the Temperature Monitoring Component triggers an emergency shutdown via the Safety Manager within the 50ms deadline.",
  type: :functional, status: :draft, priority: :must_have, asil: :asil_d,
  custom: { "Verification Method" => "Testing" }
)

# --- System Test Specifications ---
st_mod = module_map["sys_test"]
st_section = st_mod.sections.find_by!(name: "System Test Cases")

st1 = create_req(
  project: iso_project, section: st_section, user: pm,
  title: "Thermal runaway propagation prevention system test",
  body: "Verify end-to-end that when a simulated thermal runaway event occurs on a single cell, the BMS detects the condition, activates cooling, opens contactors, and prevents temperature rise in adjacent cells.",
  type: :safety, status: :draft, priority: :must_have, asil: :asil_d,
  custom: { "Verification Method" => "Testing", "Compliance Reference" => "ISO 26262-4:2018 Clause 8" }
)

st2 = create_req(
  project: iso_project, section: st_section, user: pm,
  title: "Overcharge protection system test",
  body: "Verify that the BMS disconnects the charging path within 10ms when a cell voltage exceeds 4.20V during charging at maximum rate, under ambient temperatures of -20C, +25C, and +60C.",
  type: :safety, status: :draft, priority: :must_have, asil: :asil_c,
  custom: { "Verification Method" => "Testing" }
)

puts "  Created #{iso_project.requirements.count} requirements across #{iso_project.requirement_modules.count} modules"

# --- Traceability Links ---
# Safety goals → Functional safety requirements (derives_from)
TraceabilityLink.create!(source_requirement: fsr1, target_requirement: sg1, link_type: :derives_from, created_by: pm, description: "Temperature monitoring derives from thermal runaway prevention safety goal")
TraceabilityLink.create!(source_requirement: fsr2, target_requirement: sg2, link_type: :derives_from, created_by: pm, description: "Overvoltage protection derives from overcharge prevention safety goal")
TraceabilityLink.create!(source_requirement: fsr3, target_requirement: sg3, link_type: :derives_from, created_by: pm, description: "SoC estimation derives from accurate reporting safety goal")
TraceabilityLink.create!(source_requirement: tsr1, target_requirement: sg1, link_type: :derives_from, created_by: pm, description: "Thermal shutdown threshold derives from thermal runaway prevention")

# System req → Software req (derives_from)
TraceabilityLink.create!(source_requirement: swr1, target_requirement: fsr1, link_type: :derives_from, created_by: engineer, description: "SW sensor plausibility check derives from HW temperature monitoring requirement")
TraceabilityLink.create!(source_requirement: swr2, target_requirement: fsr2, link_type: :derives_from, created_by: engineer, description: "SW voltage watchdog derives from overvoltage protection requirement")
TraceabilityLink.create!(source_requirement: swr3, target_requirement: fsr3, link_type: :derives_from, created_by: engineer, description: "SW coulomb counting derives from SoC estimation requirement")

# Software req → Architecture (satisfies)
TraceabilityLink.create!(source_requirement: arch1, target_requirement: swr1, link_type: :satisfies, created_by: engineer, description: "Temperature monitoring component satisfies sensor plausibility SW requirement")
TraceabilityLink.create!(source_requirement: arch2, target_requirement: swr2, link_type: :satisfies, created_by: engineer, description: "Voltage monitoring component satisfies voltage watchdog SW requirement")

# Architecture → Unit tests (verifies)
TraceabilityLink.create!(source_requirement: ut1, target_requirement: swr1, link_type: :verifies, created_by: engineer, description: "Unit test verifies temperature plausibility check implementation")
TraceabilityLink.create!(source_requirement: ut2, target_requirement: swr3, link_type: :verifies, created_by: engineer, description: "Unit test verifies coulomb counting accuracy")

# Architecture → Integration tests (verifies)
TraceabilityLink.create!(source_requirement: it1, target_requirement: arch1, link_type: :verifies, created_by: engineer, description: "Integration test verifies temperature monitoring to safety manager path")

# System requirements → System tests (verifies)
TraceabilityLink.create!(source_requirement: st1, target_requirement: sg1, link_type: :verifies, created_by: pm, description: "System test verifies thermal runaway propagation prevention")
TraceabilityLink.create!(source_requirement: st2, target_requirement: sg2, link_type: :verifies, created_by: pm, description: "System test verifies overcharge protection")

# Cross-module refinement
TraceabilityLink.create!(source_requirement: arch3, target_requirement: tsr1, link_type: :refines, created_by: engineer, description: "Safety manager watchdog refines thermal management shutdown requirement")

puts "  Created #{TraceabilityLink.count} traceability links"

# --- Review: Safety Requirements Review ---
review = Review.create!(
  project: iso_project,
  title: "BMS Safety Requirements Review — Milestone 1",
  description: "Initial review of all ASIL-D and ASIL-C safety goals and functional safety requirements for the Battery Management System. This review covers the thermal runaway prevention, overcharge protection, and SoC reporting safety chains.",
  status: :in_progress,
  created_by: pm,
  baseline_snapshot: {}
)

# Add participants
ReviewParticipant.create!(review: review, user: pm, role: :author)
ReviewParticipant.create!(review: review, user: reviewer_user, role: :reviewer)
ReviewParticipant.create!(review: review, user: admin, role: :approver)
ReviewParticipant.create!(review: review, user: viewer_user, role: :observer)

# Add safety-critical requirements to review (approved ones for meaningful diff)
safety_reqs = [sg1, sg2, sg3, fsr1, fsr2, tsr1, swr1, swr2]
review_items = safety_reqs.map do |req|
  item = ReviewItem.create!(review: review, requirement: req)
  item.snapshot_requirement!
  item
end

# Snapshot the review baseline
review.snapshot_requirements!

# Add review decisions on some items
review_items[0].update!(status: :approved)  # SG-01
review_items[1].update!(status: :approved)  # SG-02
review_items[2].update!(status: :needs_changes) # SG-03
review_items[3].update!(status: :approved)  # FSR-01
# Items 4-7 remain pending

# Add review comments
ReviewComment.create!(
  review_item: review_items[0],
  user: reviewer_user,
  body: "Safety goal is well-defined with clear scope. The thermal runaway propagation boundary is appropriately set at the cell-to-cell level within the pack."
)

ReviewComment.create!(
  review_item: review_items[0],
  user: admin,
  body: "Agreed. This aligns with our HARA results from the preliminary hazard analysis workshop. ASIL-D classification is correct per the severity/exposure/controllability assessment."
)

needs_changes_comment = ReviewComment.create!(
  review_item: review_items[2],
  user: reviewer_user,
  body: "The +/-3% accuracy target needs clarification. Is this over the full SoC range (0-100%) or a specific operating window? At very low SoC (<5%), 3% absolute error could be significant for range estimation.",
  resolved: false
)

ReviewComment.create!(
  review_item: review_items[2],
  user: engineer,
  body: "Good catch. We should specify that the 3% accuracy applies to the 10-90% SoC range, with a wider tolerance of +/-5% outside that range. I'll update the requirement text.",
  parent_comment: needs_changes_comment
)

ReviewComment.create!(
  review_item: review_items[4],
  user: reviewer_user,
  body: "The 10ms response time for overvoltage protection activation — has this been validated against the contactor switching time? We need to confirm the main contactor can actually achieve this."
)

ReviewComment.create!(
  review_item: review_items[6],
  user: admin,
  body: "The 500ms debounce time for sensor plausibility seems reasonable for thermal events, but we should cross-reference this with the thermal time constant of the cell group to ensure we don't miss rapid events."
)

puts "  Created review '#{review.title}' with #{review.review_items.count} items, #{review.review_participants.count} participants, #{ReviewComment.count} comments"

# --- Second Review (completed) ---
completed_review = Review.create!(
  project: iso_project,
  title: "BMS Interface Requirements Review",
  description: "Review of CAN bus interface requirements and SPI communication specifications for the BMS system.",
  status: :completed,
  created_by: pm,
  baseline_snapshot: {}
)

ReviewParticipant.create!(review: completed_review, user: pm, role: :author)
ReviewParticipant.create!(review: completed_review, user: reviewer_user, role: :reviewer)

iface_items = [swr5, arch4].map do |req|
  item = ReviewItem.create!(review: completed_review, requirement: req)
  item.snapshot_requirement!
  item
end

completed_review.snapshot_requirements!
iface_items[0].update!(status: :approved)
iface_items[1].update!(status: :approved)

ReviewComment.create!(
  review_item: iface_items[0],
  user: reviewer_user,
  body: "CAN message rates are appropriate for the data types. The 10ms rate for BMS_Status may need adjustment based on bus load analysis."
)

puts "  Created completed review '#{completed_review.title}'"

# --- AI Analysis Results (cached samples) ---
AiAnalysisResult.create!(
  requirement: sg1,
  analysis_type: "quality_analysis",
  status: :completed,
  completed_at: 2.hours.ago,
  result_data: {
    overall_score: 87,
    summary: "Well-written safety requirement with clear scope and measurable criteria. Minor improvement possible in specifying operating condition boundaries.",
    checks: [
      { rule: "ambiguity", score: 90, passed: true, issues: [], suggestions: ["Consider defining 'all operating conditions' with specific temperature/vibration ranges"] },
      { rule: "completeness", score: 85, passed: true, issues: [], suggestions: ["Add reference to specific cell chemistries covered"] },
      { rule: "singularity", score: 95, passed: true, issues: [], suggestions: [] },
      { rule: "correctness", score: 88, passed: true, issues: [], suggestions: [] },
      { rule: "verifiability", score: 80, passed: true, issues: ["'All operating conditions' may be difficult to enumerate for testing"], suggestions: ["Define a reference operating envelope document"] },
      { rule: "conformance", score: 85, passed: true, issues: [], suggestions: ["Consider using 'shall' consistently — the requirement uses 'shall' correctly"] }
    ],
    suggestions: [
      "Define a reference to the operating conditions specification for test coverage",
      "Add a note about which cell chemistries this requirement applies to"
    ]
  }
)

AiAnalysisResult.create!(
  requirement: fsr3,
  analysis_type: "quality_analysis",
  status: :completed,
  completed_at: 1.hour.ago,
  result_data: {
    overall_score: 62,
    summary: "Requirement has ambiguity in algorithm selection criteria and lacks specific accuracy targets. The dual approach is good but needs tighter specification.",
    checks: [
      { rule: "ambiguity", score: 50, passed: false, issues: ["'lowest estimated uncertainty' is subjective — how is uncertainty estimated?", "'both' methods implies simultaneous execution but doesn't specify timing"], suggestions: ["Define the uncertainty metric quantitatively"] },
      { rule: "completeness", score: 65, passed: false, issues: ["Missing accuracy target for the combined estimation", "No specification of how to handle divergence between methods"], suggestions: ["Add convergence criteria for the two methods"] },
      { rule: "singularity", score: 70, passed: true, issues: ["Contains two distinct concepts: estimation method and selection criteria"], suggestions: ["Consider splitting into separate requirements for estimation and selection"] },
      { rule: "correctness", score: 75, passed: true, issues: [], suggestions: [] },
      { rule: "verifiability", score: 45, passed: false, issues: ["'lowest estimated uncertainty' cannot be verified without a defined metric"], suggestions: ["Specify an uncertainty threshold in percentage or voltage"] },
      { rule: "conformance", score: 80, passed: true, issues: [], suggestions: [] }
    ],
    suggestions: [
      "Split into two requirements: one for the estimation algorithms, one for the selection logic",
      "Define a quantitative uncertainty metric (e.g., confidence interval in % SoC)",
      "Add a requirement for the fallback behavior when both methods report high uncertainty"
    ]
  }
)

AiAnalysisResult.create!(
  requirement: sg1,
  analysis_type: "link_suggestion",
  status: :completed,
  completed_at: 2.hours.ago,
  result_data: {
    suggestions: [
      { target_uid: arch3.uid, link_type: "derives_from", confidence: 0.88, rationale: "The safety manager watchdog is a direct implementation mechanism for the thermal runaway prevention safety goal" },
      { target_uid: swr6.uid, link_type: "derives_from", confidence: 0.72, rationale: "WCET constraints are driven by the real-time response requirements of thermal protection" }
    ]
  }
)

puts "  Created #{AiAnalysisResult.count} AI analysis results"

# --- Test Cases ---
# Unit tests linked to SW requirements
tc1 = TestCase.create!(
  project: iso_project, requirement: swr1, created_by: engineer,
  title: "Verify temperature sensor plausibility check detects fault",
  description: "Test that the plausibility check flags a sensor fault when redundant NTC readings diverge by more than 5°C for 500ms.",
  preconditions: "BMS running in normal mode. Both NTC sensors reading 25°C ± 0.5°C initially.",
  steps: "1. Inject a 6°C offset on sensor B via test harness\n2. Monitor plausibility check output for 600ms\n3. Verify fault flag is set after 500ms debounce\n4. Verify the higher sensor reading is selected for safety decisions",
  expected_result: "Sensor fault flag set at 500ms ± 10ms. Higher reading (31°C) used for thermal protection decisions.",
  test_type: :unit, status: :passed, priority: :must_have
)

tc2 = TestCase.create!(
  project: iso_project, requirement: swr1, created_by: engineer,
  title: "Verify plausibility check passes for normal sensor deviation",
  description: "Test that normal sensor variation within 5°C does not trigger a false fault.",
  preconditions: "BMS running in normal mode. Both sensors reading 40°C.",
  steps: "1. Inject a 4.5°C offset on sensor B\n2. Monitor plausibility check for 2 seconds\n3. Verify no fault flag is raised",
  expected_result: "No sensor fault flag. Both readings used in normal averaging mode.",
  test_type: :unit, status: :passed, priority: :must_have
)

tc3 = TestCase.create!(
  project: iso_project, requirement: swr2, created_by: engineer,
  title: "Verify voltage monitoring watchdog triggers emergency shutdown",
  description: "Test that the watchdog triggers shutdown when the voltage monitoring task misses 3 consecutive deadlines.",
  preconditions: "BMS running. Voltage monitoring task executing at 100ms interval.",
  steps: "1. Suspend voltage monitoring task via debugger\n2. Wait for 300ms (3 missed periods)\n3. Verify emergency shutdown is triggered\n4. Verify main contactors are commanded open",
  expected_result: "Emergency shutdown triggered at 300ms ± 10ms. Contactor open command issued.",
  test_type: :unit, status: :passed, priority: :must_have
)

tc4 = TestCase.create!(
  project: iso_project, requirement: swr3, created_by: engineer,
  title: "Verify coulomb counting integration accuracy at 1C rate",
  description: "Test trapezoidal integration accuracy over a 1-hour constant-current charge cycle.",
  preconditions: "Battery at 20% SoC. Constant 1C charge current applied.",
  steps: "1. Start coulomb counting integration\n2. Apply constant 1C current for 3600 seconds\n3. Compare accumulated charge to theoretical value\n4. Calculate percentage error",
  expected_result: "Accumulated charge within ±0.1% of theoretical value (I × t).",
  test_type: :unit, status: :failed, priority: :must_have
)

tc5 = TestCase.create!(
  project: iso_project, requirement: swr4, created_by: engineer,
  title: "Verify cell balancing algorithm selects correct cells",
  description: "Test that cells exceeding module average by more than 10mV are selected for balancing.",
  preconditions: "Module with 12 cells. Average voltage 3.80V.",
  steps: "1. Set cell 3 to 3.815V and cell 7 to 3.820V\n2. Run balancing algorithm\n3. Verify cells 3 and 7 are selected for balancing\n4. Verify other cells are not selected",
  expected_result: "Cells 3 and 7 balancing FETs activated. All other cells FETs remain off.",
  test_type: :unit, status: :not_run, priority: :should_have
)

# Integration tests
tc6 = TestCase.create!(
  project: iso_project, requirement: arch1, created_by: engineer,
  title: "Verify temperature monitoring to safety manager shutdown path",
  description: "Integration test for the complete temperature exceedance → emergency shutdown path.",
  preconditions: "BMS fully operational. All temperatures nominal at 35°C.",
  steps: "1. Inject temperature exceedance (62°C) on cell group 4 via SPI test interface\n2. Measure time from detection to contactor open command\n3. Verify coolant pump activated to maximum\n4. Verify DTC logged via CAN",
  expected_result: "Contactor open within 50ms. Coolant pump at max. DTC 0xBMS_T01 transmitted.",
  test_type: :integration, status: :passed, priority: :must_have
)

tc7 = TestCase.create!(
  project: iso_project, requirement: arch2, created_by: engineer,
  title: "Verify voltage monitoring to contactor control path",
  description: "Integration test for overvoltage detection → charging path disconnection.",
  preconditions: "BMS in charging mode. All cell voltages at 4.10V.",
  steps: "1. Ramp cell 5 voltage to 4.22V via SPI test interface\n2. Measure time from detection to contactor command\n3. Verify charging path disconnected\n4. Verify overvoltage DTC logged",
  expected_result: "Charging contactor opened within 10ms. DTC 0xBMS_V02 transmitted on CAN.",
  test_type: :integration, status: :blocked, priority: :must_have
)

# System tests
tc8 = TestCase.create!(
  project: iso_project, requirement: sg1, created_by: pm,
  title: "End-to-end thermal runaway propagation prevention test",
  description: "System-level test verifying complete thermal protection chain from detection through safe state entry.",
  preconditions: "BMS connected to battery pack simulator. Ambient 25°C. Pack at 80% SoC.",
  steps: "1. Trigger simulated thermal event on cell group 2 (80°C ramp at 5°C/s)\n2. Monitor BMS response chain: detection → fault flag → contactor control → cooling\n3. Monitor adjacent cell group temperatures for 5 minutes\n4. Verify no propagation (adjacent groups stay below 45°C)\n5. Verify all DTCs logged correctly",
  expected_result: "Shutdown initiated within 100ms. Adjacent cells below 45°C at all times. Full DTC chain logged.",
  test_type: :safety, status: :not_run, priority: :must_have
)

tc9 = TestCase.create!(
  project: iso_project, requirement: sg2, created_by: pm,
  title: "Overcharge protection system validation at temperature extremes",
  description: "Validate overcharge protection across the full temperature range: -20°C, +25°C, +60°C.",
  preconditions: "Climate chamber available. Battery pack simulator with cell-level voltage injection.",
  steps: "1. For each temperature point (-20°C, +25°C, +60°C):\n   a. Stabilize at target temperature for 30 minutes\n   b. Apply charging current and ramp cell voltage to 4.22V\n   c. Measure response time from threshold crossing to contactor open\n   d. Verify protection activates within 10ms at all temperatures\n2. Record response times and margins",
  expected_result: "Protection activated within 10ms at all three temperature points. No cell exceeds 4.25V.",
  test_type: :safety, status: :ready, priority: :must_have
)

tc10 = TestCase.create!(
  project: iso_project, requirement: swr5, created_by: engineer,
  title: "Verify CAN bus message transmission rates",
  description: "Validate all CAN messages are transmitted at specified rates under bus load conditions.",
  preconditions: "BMS connected to CAN bus analyzer. 40% background bus load applied.",
  steps: "1. Enable CAN message recording on analyzer\n2. Run BMS for 60 seconds\n3. Analyze BMS_Status message timing (expect 10ms ± 1ms)\n4. Analyze BMS_CellVoltages timing (expect 100ms ± 5ms)\n5. Analyze BMS_Temperatures timing (expect 500ms ± 25ms)\n6. Trigger a fault and verify BMS_Faults latency < 50ms",
  expected_result: "All message rates within tolerance. Fault message latency < 50ms.",
  test_type: :integration, status: :passed, priority: :must_have
)

puts "  Created #{iso_project.test_cases.count} test cases"

# --- Change Set Rules ---
ChangeSetRule.create!(
  project: iso_project,
  min_approvals: 2,
  require_all_conversations_resolved: true,
  auto_merge_on_approval: false
)

puts "  Created change set rules for #{iso_project.name}"

# --- Change Set 1: Merged (completed PR flow) ---
merged_cs = ChangeSet.create!(
  project: iso_project,
  title: "Update SoC estimation accuracy targets",
  description: "Refines the SoC accuracy requirements based on feedback from the safety review. Narrows the operating range for the 3% accuracy target and adds explicit fallback behavior for extreme SoC values.",
  status: :merged,
  created_by: engineer,
  merged_by: pm,
  merged_at: 3.days.ago
)

# Modified requirement: update the SoC safety goal body
cs1_change1 = ChangeSetChange.create!(
  change_set: merged_cs,
  requirement: sg3,
  change_type: :modified,
  before_snapshot: {
    "uid" => sg3.uid, "title" => sg3.title,
    "body" => "The BMS shall report state-of-charge (SoC) to the vehicle controller with an accuracy of +/-3% under normal operating conditions (-20C to +60C ambient temperature range).",
    "requirement_type" => "safety", "status" => "approved", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => sg3.custom_attributes,
    "module_name" => "System Requirements", "section_name" => "Safety Goals"
  },
  after_snapshot: {
    "uid" => sg3.uid, "title" => sg3.title,
    "body" => "The BMS shall report state-of-charge (SoC) to the vehicle controller with an accuracy of +/-3% in the 10-90% SoC range and +/-5% outside that range, under normal operating conditions (-20C to +60C ambient temperature range).",
    "requirement_type" => "safety", "status" => "approved", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => sg3.custom_attributes,
    "module_name" => "System Requirements", "section_name" => "Safety Goals"
  }
)

# Modified requirement: update the SoC estimation SW requirement
cs1_change2 = ChangeSetChange.create!(
  change_set: merged_cs,
  requirement: fsr3,
  change_type: :modified,
  before_snapshot: {
    "uid" => fsr3.uid, "title" => fsr3.title,
    "body" => fsr3.body,
    "requirement_type" => "functional", "status" => "in_review", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => fsr3.custom_attributes,
    "module_name" => "System Requirements", "section_name" => "Functional Safety Requirements"
  },
  after_snapshot: {
    "uid" => fsr3.uid, "title" => "SoC estimation using dual algorithm approach with defined uncertainty metric",
    "body" => "The BMS shall estimate state-of-charge using both coulomb counting and open-circuit voltage lookup methods, selecting the result with the lowest estimated uncertainty as measured by the 95% confidence interval width. When both methods report uncertainty exceeding 5% SoC, the system shall use coulomb counting as the primary source and flag a degraded accuracy condition.",
    "requirement_type" => "functional", "status" => "in_review", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => fsr3.custom_attributes,
    "module_name" => "System Requirements", "section_name" => "Functional Safety Requirements"
  }
)

# Approvals for merged change set
ChangeSetApproval.create!(change_set: merged_cs, user: reviewer_user, status: :approved, body: "SoC accuracy refinements look good. The 10-90% range for 3% accuracy is well-justified.")
ChangeSetApproval.create!(change_set: merged_cs, user: admin, status: :approved, body: "Approved. Aligns with the review feedback on SG-03.")

# Comments on merged change set
ChangeSetComment.create!(
  change_set: merged_cs, change_set_change: cs1_change1, user: reviewer_user,
  body: "The split between 10-90% and outside ranges addresses the review comment well. Good refinement."
)
ChangeSetComment.create!(
  change_set: merged_cs, change_set_change: cs1_change2, user: admin,
  body: "The fallback to coulomb counting is a safe choice — it's more robust for extreme SoC values. The 5% uncertainty threshold should be validated against our sensor accuracy data."
)
cs1_conv = ChangeSetComment.create!(
  change_set: merged_cs, user: engineer,
  body: "This change set addresses the feedback from the safety requirements review (BMS-003 accuracy clarification). Ready for review."
)
ChangeSetComment.create!(
  change_set: merged_cs, user: pm, parent_comment: cs1_conv,
  body: "Thanks Priya. I've asked James and Sarah to review since they raised the original concern."
)

puts "  Created merged change set: '#{merged_cs.title}'"

# --- Change Set 2: In Review (active PR) ---
active_cs = ChangeSet.create!(
  project: iso_project,
  title: "Add CAN bus fault injection test coverage",
  description: "Adds new requirements for CAN bus fault injection testing and updates the interface specification to include error frame handling. Driven by the EMC test plan review.",
  status: :in_review,
  created_by: engineer
)

# New requirement added in this change set
new_req_for_cs = Requirement.create!(
  project: iso_project,
  section: sw_iface_section,
  created_by: engineer,
  title: "CAN bus error frame handling",
  body: "The BMS software shall detect and handle CAN bus error frames by incrementing the bus-off error counter and initiating a bus recovery sequence if the error count exceeds 128 within any 1-second window.",
  requirement_type: :interface,
  status: :draft,
  priority: :must_have,
  asil_level: :asil_b,
  custom_attributes: { "Verification Method" => "Testing" }
)

cs2_change1 = ChangeSetChange.create!(
  change_set: active_cs,
  requirement: new_req_for_cs,
  change_type: :created,
  before_snapshot: {},
  after_snapshot: {
    "uid" => new_req_for_cs.uid, "title" => new_req_for_cs.title,
    "body" => new_req_for_cs.body,
    "requirement_type" => "interface", "status" => "draft", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => new_req_for_cs.custom_attributes,
    "module_name" => "Software Requirements", "section_name" => "Software Interface Requirements"
  }
)

# Modified existing CAN message requirement
cs2_change2 = ChangeSetChange.create!(
  change_set: active_cs,
  requirement: swr5,
  change_type: :modified,
  before_snapshot: {
    "uid" => swr5.uid, "title" => swr5.title,
    "body" => swr5.body,
    "requirement_type" => "interface", "status" => "draft", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => swr5.custom_attributes,
    "module_name" => "Software Requirements", "section_name" => "Software Interface Requirements"
  },
  after_snapshot: {
    "uid" => swr5.uid, "title" => swr5.title,
    "body" => "The BMS software shall transmit the following CAN messages at the specified rates: BMS_Status (10ms), BMS_CellVoltages (100ms), BMS_Temperatures (500ms), BMS_Faults (event-triggered, max latency 50ms). All messages shall include a rolling 4-bit alive counter and 8-bit CRC for end-to-end protection.",
    "requirement_type" => "interface", "status" => "draft", "priority" => "must_have", "asil_level" => "asil_b",
    "custom_attributes" => swr5.custom_attributes,
    "module_name" => "Software Requirements", "section_name" => "Software Interface Requirements"
  }
)

# Approvals: one approved, one pending
ChangeSetApproval.create!(change_set: active_cs, user: reviewer_user, status: :approved, body: "CAN error handling looks correct. The bus-off recovery sequence follows ISO 11898.")
ChangeSetApproval.create!(change_set: active_cs, user: admin, status: :pending)

# Comments with an unresolved conversation thread
cs2_inline = ChangeSetComment.create!(
  change_set: active_cs, change_set_change: cs2_change2, user: reviewer_user,
  body: "The alive counter and CRC addition is good for E2E protection, but should we reference the AUTOSAR E2E profile specifically? Profile 1 or Profile 2 would be standard for this use case."
)
ChangeSetComment.create!(
  change_set: active_cs, change_set_change: cs2_change2, user: engineer,
  parent_comment: cs2_inline,
  body: "Good point. I'll reference AUTOSAR E2E Profile 2 since it's the standard for periodic CAN messages in our domain. Will update the after_snapshot."
)
ChangeSetComment.create!(
  change_set: active_cs, user: pm,
  body: "This change set was requested by the EMC team after their fault injection test plan review. Priority is high for the upcoming qualification milestone."
)

puts "  Created in-review change set: '#{active_cs.title}'"

# --- Change Set 3: Draft (just started) ---
draft_cs = ChangeSet.create!(
  project: iso_project,
  title: "Thermal management algorithm improvements",
  description: "Proposed improvements to the thermal management shutdown thresholds based on cell characterization test results. Adjusts the emergency shutdown temperature from 60°C to 55°C for improved safety margin.",
  status: :draft,
  created_by: pm
)

cs3_change1 = ChangeSetChange.create!(
  change_set: draft_cs,
  requirement: tsr1,
  change_type: :modified,
  before_snapshot: {
    "uid" => tsr1.uid, "title" => tsr1.title,
    "body" => tsr1.body,
    "requirement_type" => "safety", "status" => "approved", "priority" => "must_have", "asil_level" => "asil_d",
    "custom_attributes" => tsr1.custom_attributes,
    "module_name" => "System Requirements", "section_name" => "Technical Safety Requirements"
  },
  after_snapshot: {
    "uid" => tsr1.uid, "title" => tsr1.title,
    "body" => "The BMS shall initiate an emergency shutdown sequence when any cell temperature exceeds 55C (reduced from 60C based on cell characterization data), opening main contactors within 50ms and activating the coolant pump to maximum flow rate.",
    "requirement_type" => "safety", "status" => "approved", "priority" => "must_have", "asil_level" => "asil_d",
    "custom_attributes" => tsr1.custom_attributes,
    "module_name" => "System Requirements", "section_name" => "Technical Safety Requirements"
  }
)

puts "  Created draft change set: '#{draft_cs.title}'"

# --- Second Project (blank, smaller) ---
adas_project = Project.create!(
  organization: demo_org,
  name: "ADAS Radar Processing Unit",
  description: "Advanced Driver Assistance System radar signal processing unit. Handles object detection, tracking, and classification from 77GHz radar sensors.",
  prefix: "ADAS",
  status: :active,
  attribute_schema: [
    { "name" => "Sensor Type", "type" => "enum", "required" => false, "options" => "Radar,Camera,Lidar,Ultrasonic" },
    { "name" => "Detection Range", "type" => "text", "required" => false }
  ]
)

adas_mod = adas_project.requirement_modules.create!(name: "System Requirements", position: 1)
adas_section = adas_mod.sections.create!(name: "Object Detection", position: 1)

create_req(
  project: adas_project, section: adas_section, user: engineer,
  title: "Maximum detection range for vehicles",
  body: "The radar processing unit shall detect passenger vehicles at a maximum range of 250m with a probability of detection of 95% under clear weather conditions.",
  type: :functional, status: :draft, priority: :must_have, asil: :asil_b,
  custom: { "Sensor Type" => "Radar", "Detection Range" => "250m" }
)

create_req(
  project: adas_project, section: adas_section, user: engineer,
  title: "Object classification accuracy",
  body: "The radar processing unit shall classify detected objects into the categories: vehicle, pedestrian, cyclist, static obstacle with an overall classification accuracy of 98% at ranges up to 100m.",
  type: :functional, status: :draft, priority: :must_have, asil: :asil_b,
  custom: { "Sensor Type" => "Radar", "Detection Range" => "100m" }
)

create_req(
  project: adas_project, section: adas_section, user: engineer,
  title: "Object tracking update rate",
  body: "The radar processing unit shall update tracked object positions at a minimum rate of 20Hz with a maximum latency of 50ms from sensor data acquisition to track update output.",
  type: :non_functional, status: :draft, priority: :must_have, asil: :asil_b,
  custom: { "Sensor Type" => "Radar" }
)

puts "  Created project: #{adas_project.name} with #{adas_project.requirements.count} requirements"

# --- ADAS Project Test Cases ---
adas_reqs = adas_project.requirements.order(:position)
TestCase.create!(
  project: adas_project, requirement: adas_reqs.first, created_by: engineer,
  title: "Verify maximum vehicle detection range",
  description: "Validate radar detects passenger vehicles at 250m with 95% probability.",
  preconditions: "Radar mounted on test vehicle. Standard passenger vehicle target at calibrated distances.",
  steps: "1. Position target vehicle at 250m\n2. Collect 1000 radar frames\n3. Count detections\n4. Calculate detection probability",
  expected_result: "Detection probability >= 95% at 250m.",
  test_type: :system, status: :not_run, priority: :must_have
)

TestCase.create!(
  project: adas_project, requirement: adas_reqs.second, created_by: engineer,
  title: "Verify object classification accuracy at 100m",
  description: "Validate classification accuracy for vehicles, pedestrians, cyclists, and static obstacles.",
  preconditions: "Radar operational. Four target types available at 100m.",
  steps: "1. Present each target type 250 times at 100m\n2. Record classifications\n3. Calculate per-class and overall accuracy",
  expected_result: "Overall classification accuracy >= 98%.",
  test_type: :system, status: :draft, priority: :must_have
)

puts "  Created #{adas_project.test_cases.count} ADAS test cases"

# --- Archived Project ---
legacy_project = Project.create!(
  organization: demo_org,
  name: "Legacy Power Steering ECU (Archived)",
  description: "Previous-generation electric power steering ECU. Project completed and archived after production release.",
  prefix: "EPS",
  status: :archived,
  attribute_schema: []
)

puts "  Created archived project: #{legacy_project.name}"

puts ""
puts "Demo data created successfully!"
puts "  Organization: #{demo_org.name}"
puts "  Users: admin@acme-automotive.dev / pm@acme-automotive.dev / engineer@acme-automotive.dev / reviewer@acme-automotive.dev / viewer@acme-automotive.dev"
puts "  Password for all users: password123"
puts "  Projects: #{Project.where(organization: demo_org).count}"
puts "  Requirements: #{Requirement.joins(:project).where(projects: { organization: demo_org }).count}"
puts "  Traceability Links: #{TraceabilityLink.count}"
puts "  Reviews: #{Review.joins(:project).where(projects: { organization: demo_org }).count}"
puts "  Change Sets: #{ChangeSet.joins(:project).where(projects: { organization: demo_org }).count}"
puts "  Test Cases: #{TestCase.joins(:project).where(projects: { organization: demo_org }).count}"
puts "  AI Analysis Results: #{AiAnalysisResult.count}"
