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
puts "  AI Analysis Results: #{AiAnalysisResult.count}"
