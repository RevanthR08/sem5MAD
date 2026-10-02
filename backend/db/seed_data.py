"""Seed realistic data for Civic Connect."""
import os
from pathlib import Path
import psycopg2
from datetime import datetime, timedelta
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
load_dotenv()

DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")

# Shared password for the four seeded demo accounts (shown on the sign-in screen)
DEMO_PASSWORD = "CivicPass2026!"
DEMO_USER_IDS = [f"10000000-0000-0000-0000-00000000000{i}" for i in range(1, 5)]


def set_demo_passwords(cur):
    from backend.app.core.security import hash_password
    for user_id in DEMO_USER_IDS:
        cur.execute("UPDATE users SET password_hash = %s WHERE id = %s;", (hash_password(DEMO_PASSWORD), user_id))

def seed():
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    print("Seeding Civic Connect master data...")

    # Clear existing demo data to allow clean re-runs
    cur.execute("""
        TRUNCATE TABLE report_subscriptions, report_timeline, report_media, reports, 
        routing_rules, subcategories, categories, users, departments, wards, zones, authorities 
        CASCADE;
    """)

    # 1. Authority
    cur.execute("""
        INSERT INTO authorities (id, code, name, city, state)
        VALUES ('a0000000-0000-0000-0000-000000000001', 'GCC', 'Greater Chennai Corporation', 'Chennai', 'Tamil Nadu')
        RETURNING id;
    """)
    authority_id = 'a0000000-0000-0000-0000-000000000001'

    # 2. Zones
    cur.execute("""
        INSERT INTO zones (id, authority_id, name, zone_number) VALUES
        ('b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'Teynampet', 9),
        ('b0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'Kodambakkam', 10),
        ('b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'Anna Nagar', 8);
    """)

    # 3. Wards
    cur.execute("""
        INSERT INTO wards (id, zone_id, authority_id, ward_number, name, center_lat, center_lng) VALUES
        ('c0000000-0000-0000-0000-000000000114', 'b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'Ward 114', 'Teynampet East', 13.0418, 80.2507),
        ('c0000000-0000-0000-0000-000000000123', 'b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'Ward 123', 'Mylapore / Anna Salai', 13.0336, 80.2677),
        ('c0000000-0000-0000-0000-000000000124', 'b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000001', 'Ward 124', 'Alwarpet & Gopalapuram', 13.0440, 80.2560),
        ('c0000000-0000-0000-0000-000000000130', 'b0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000001', 'Ward 130', 'T. Nagar Central', 13.0405, 80.2337);
    """)

    # 4. Departments
    cur.execute("""
        INSERT INTO departments (id, authority_id, code, name, email, head_officer_name) VALUES
        ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'roads', 'Roads & Bridges Department', 'roads.gcc@chennaicorporation.gov.in', 'Er. Rajesh V'),
        ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'waste', 'Solid Waste Management', 'waste.gcc@chennaicorporation.gov.in', 'Dr. Kavitha M'),
        ('d0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'drainage', 'Stormwater Drainage & Floods', 'drainage.gcc@chennaicorporation.gov.in', 'Er. Narayanan S'),
        ('d0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'lighting', 'Electrical & Street Lighting', 'electrical.gcc@chennaicorporation.gov.in', 'Er. Balaji K'),
        ('d0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000001', 'water', 'Chennai Metro Water & Sewerage', 'metrowater.gcc@chennaicorporation.gov.in', 'Er. Sundar Rajan'),
        ('d0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000001', 'safety', 'Public Safety & Hazards', 'safety.gcc@chennaicorporation.gov.in', 'Inspector Ramesh');
    """)

    # 5. Users
    cur.execute("""
        INSERT INTO users (id, email, phone, full_name, role, department_id, authority_id, ward_id, avatar_url) VALUES
        ('10000000-0000-0000-0000-000000000001', 'citizen@civicconnect.org', '+919876543210', 'Revanth Citizen', 'CITIZEN', NULL, 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000123', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
        ('10000000-0000-0000-0000-000000000002', 'officer.roads@gcc.gov.in', '+919840112233', 'Rajesh V (Roads Officer)', 'DEPARTMENT_OFFICER', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000123', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
        ('10000000-0000-0000-0000-000000000003', 'worker.roads@gcc.gov.in', '+919840998877', 'Murugan S (Road Team 4)', 'FIELD_WORKER', 'd0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000123', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'),
        ('10000000-0000-0000-0000-000000000004', 'admin.gcc@chennaicorporation.gov.in', '+919840001122', 'Commissioner Admin', 'SUPER_ADMIN', NULL, 'a0000000-0000-0000-0000-000000000001', NULL, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150');
    """)
    set_demo_passwords(cur)

    # 6. Categories & Subcategories
    categories_data = [
        ('e0000000-0000-0000-0000-000000000001', 'roads', 'Roads & Footpaths', 'Hammer', 'Potholes, broken roads, damaged kerbs, cracked pavements', 24, 50, [
            ('e001', 'pothole', 'Pothole on Carriageway', 24, 'HIGH'),
            ('e002', 'cave_in', 'Road Cave-in / Depression', 12, 'CRITICAL'),
            ('e003', 'damaged_footpath', 'Damaged Footpath / Paver Blocks', 72, 'MEDIUM'),
            ('e004', 'open_manhole', 'Open Manhole / Missing Cover', 4, 'CRITICAL'),
            ('e005', 'road_obstruction', 'Debris / Road Obstruction', 12, 'HIGH')
        ]),
        ('e0000000-0000-0000-0000-000000000002', 'waste', 'Waste Management', 'Trash2', 'Overflowing dumpsters, uncollected garbage, illegal dumping', 24, 60, [
            ('e011', 'garbage_overflow', 'Dumpster Overflowing', 12, 'HIGH'),
            ('e012', 'uncollected_bins', 'Door-to-Door Uncollected Waste', 24, 'MEDIUM'),
            ('e013', 'illegal_dumping', 'Construction Debris / Illegal Dumping', 48, 'MEDIUM'),
            ('e014', 'dead_animal', 'Dead Animal Removal', 6, 'HIGH')
        ]),
        ('e0000000-0000-0000-0000-000000000003', 'lighting', 'Street Lighting', 'Lightbulb', 'Non-functioning streetlights, flickering lamps, exposed wires', 48, 40, [
            ('e021', 'light_out', 'Streetlight Completely Off', 48, 'MEDIUM'),
            ('e022', 'flickering', 'Flickering / Dim Lamp', 72, 'LOW'),
            ('e023', 'exposed_wiring', 'Exposed Wiring / Shock Hazard', 6, 'CRITICAL'),
            ('e024', 'fallen_pole', 'Fallen or Leaning Light Pole', 4, 'CRITICAL')
        ]),
        ('e0000000-0000-0000-0000-000000000004', 'drainage', 'Drainage & Floods', 'Droplets', 'Clogged storm drains, stagnant water, flooding, broken slabs', 24, 100, [
            ('e031', 'blocked_drain', 'Clogged Stormwater Drain', 24, 'HIGH'),
            ('e032', 'waterlogging', 'Severe Road Waterlogging', 12, 'HIGH'),
            ('e033', 'broken_drain_slab', 'Broken Drain Cover Slab', 36, 'HIGH'),
            ('e034', 'sewage_overflow', 'Sewage Overflow on Street', 12, 'CRITICAL')
        ]),
        ('e0000000-0000-0000-0000-000000000005', 'water', 'Water Supply', 'Waves', 'Pipe leaks, water contamination, low pressure, valve damage', 24, 60, [
            ('e041', 'pipeline_burst', 'Main Pipeline Burst / Major Leak', 8, 'CRITICAL'),
            ('e042', 'valve_leak', 'Distribution Valve Leaking', 24, 'MEDIUM'),
            ('e043', 'contaminated_water', 'Contaminated / Muddy Tap Water', 12, 'HIGH'),
            ('e044', 'no_supply', 'Complete Supply Interruption', 24, 'HIGH')
        ]),
        ('e0000000-0000-0000-0000-000000000006', 'safety', 'Public Safety & Trees', 'ShieldAlert', 'Fallen trees, dangerous structures, stray cattle, stray dogs', 24, 80, [
            ('e051', 'fallen_tree', 'Fallen Tree Blocking Road', 6, 'HIGH'),
            ('e052', 'dangerous_branch', 'Hanging Dangerous Tree Branch', 24, 'MEDIUM'),
            ('e053', 'stray_cattle', 'Stray Cattle / Dog Hazard', 24, 'MEDIUM'),
            ('e054', 'construction_hazard', 'Unsecured Construction Pit', 12, 'HIGH')
        ])
    ]

    for cat_id, cat_code, cat_name, icon, desc, sla, radius, subs in categories_data:
        cur.execute("""
            INSERT INTO categories (id, code, name, icon, description, default_sla_hours, duplicate_radius_meters)
            VALUES (%s, %s, %s, %s, %s, %s, %s);
        """, (cat_id, cat_code, cat_name, icon, desc, sla, radius))

        for sub_id_suffix, sub_code, sub_name, sub_sla, prio in subs:
            sub_id = f"f0000000-0000-0000-0000-00000000{sub_id_suffix}"
            cur.execute("""
                INSERT INTO subcategories (id, category_id, code, name, sla_hours, priority_level)
                VALUES (%s, %s, %s, %s, %s, %s);
            """, (sub_id, cat_id, sub_code, sub_name, sub_sla, prio))

    # 7. Routing Rules
    routing_mapping = [
        ('e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001'), # Roads -> Roads Dept
        ('e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002'), # Waste -> Waste Dept
        ('e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000004'), # Lighting -> Electrical Dept
        ('e0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000003'), # Drainage -> Drainage Dept
        ('e0000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000005'), # Water -> Metro Water
        ('e0000000-0000-0000-0000-000000000006', 'd0000000-0000-0000-0000-000000000006'), # Safety -> Public Safety
    ]
    for cat_id, dept_id in routing_mapping:
        cur.execute("""
            INSERT INTO routing_rules (authority_id, category_id, department_id, priority, active)
            VALUES ('a0000000-0000-0000-0000-000000000001', %s, %s, 1, TRUE);
        """, (cat_id, dept_id))

    # 8. Sample Civic Reports with full lifecycles & realistic images
    now = datetime.utcnow()

    sample_reports = [
        {
            "public_id": "CC-2026-0001842",
            "title": "Severe Pothole Cluster near Bus Stop",
            "description": "Deep crater-like potholes on the main left carriageway right next to the Anna Salai bus shelter. Vehicles are swerving abruptly causing severe traffic bottlenecks and near-accidents for two-wheelers.",
            "status": "IN_PROGRESS",
            "priority": "HIGH",
            "severity": "HIGH",
            "category_id": "e0000000-0000-0000-0000-000000000001",
            "subcategory_id": "f0000000-0000-0000-0000-00000000e001",
            "lat": 13.0418,
            "lng": 80.2507,
            "address": "Opposite Gemini Flyover, Anna Salai, Teynampet",
            "landmark": "Near Anna Salai Bus Shelter & US Consulate Signal",
            "ward_id": "c0000000-0000-0000-0000-000000000114",
            "zone_id": "b0000000-0000-0000-0000-000000000009",
            "department_id": "d0000000-0000-0000-0000-000000000001",
            "assigned_to": "10000000-0000-0000-0000-000000000003",
            "assigned_team": "Road Maintenance Rapid Team 4",
            "sla_hours": 24,
            "sla_deadline": now + timedelta(hours=8),
            "media": [
                ("PHOTO", "https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?w=800", "Deep road pothole near bus stop", "SUBMISSION"),
                ("PHOTO", "https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800", "Team 4 asphalt patch compaction", "BEFORE_WORK")
            ],
            "timeline": [
                ("REPORT_CREATED", "Report submitted by citizen via Mobile Web", "SUBMITTED", None),
                ("ROUTED", "Automated GIS Engine routed to Roads & Bridges Dept (Ward 114)", "ROUTED", "SUBMITTED"),
                ("ACKNOWLEDGED", "Er. Rajesh V (Roads Officer) acknowledged ticket", "ACKNOWLEDGED", "ROUTED"),
                ("ASSIGNED", "Assigned to Field Worker Murugan S (Road Rapid Team 4)", "ASSIGNED", "ACKNOWLEDGED"),
                ("WORK_STARTED", "Cold-mix asphalt patch team mobilized on site with barricading", "IN_PROGRESS", "ASSIGNED")
            ],
            "custom_fields": '{"pothole_width": "1.2 meters", "traffic_impact": "Severe bottleneck", "danger_to_pedestrians": true}'
        },
        {
            "public_id": "CC-2026-0001843",
            "title": "Overflowing Garbage Dumpster on Residential Corner",
            "description": "Commercial waste dumped outside the designated bin. Stray animals are scattering bags across the street creating foul odour and sanitary risk.",
            "status": "ASSIGNED",
            "priority": "HIGH",
            "severity": "HIGH",
            "category_id": "e0000000-0000-0000-0000-000000000002",
            "subcategory_id": "f0000000-0000-0000-0000-00000000e011",
            "lat": 13.0336,
            "lng": 80.2677,
            "address": "South Mada Street, Mylapore",
            "landmark": "Near Kapaleeshwarar Temple Tank Corner",
            "ward_id": "c0000000-0000-0000-0000-000000000123",
            "zone_id": "b0000000-0000-0000-0000-000000000009",
            "department_id": "d0000000-0000-0000-0000-000000000002",
            "assigned_to": "10000000-0000-0000-0000-000000000003",
            "assigned_team": "Sanitation Compactor Truck Unit 2",
            "sla_hours": 12,
            "sla_deadline": now + timedelta(hours=4),
            "media": [
                ("PHOTO", "https://images.unsplash.com/photo-1605600659873-d808a13e4d2a?w=800", "Overflowing garbage bin corner", "SUBMISSION")
            ],
            "timeline": [
                ("REPORT_CREATED", "Report filed with photo evidence", "SUBMITTED", None),
                ("ROUTED", "Routed to Solid Waste Management (Ward 123)", "ROUTED", "SUBMITTED"),
                ("ACKNOWLEDGED", "Dr. Kavitha M dispatched compactor truck crew", "ASSIGNED", "ROUTED")
            ],
            "custom_fields": '{"waste_type": "Mixed household & commercial", "overflowing": true, "health_hazard": true}'
        },
        {
            "public_id": "CC-2026-0001844",
            "title": "Open Manhole Missing Heavy Cast Iron Cover",
            "description": "Urgent life safety hazard! A storm manhole has no lid on an unlit pedestrian walkway. A small tree branch was placed by locals as a makeshift warning sign.",
            "status": "SUBMITTED",
            "priority": "CRITICAL",
            "severity": "CRITICAL",
            "category_id": "e0000000-0000-0000-0000-000000000001",
            "subcategory_id": "f0000000-0000-0000-0000-00000000e004",
            "lat": 13.0405,
            "lng": 80.2337,
            "address": "Pondy Bazaar Pedestrian Plaza, T. Nagar",
            "landmark": "Near Panagal Park Intersection",
            "ward_id": "c0000000-0000-0000-0000-000000000130",
            "zone_id": "b0000000-0000-0000-0000-000000000010",
            "department_id": "d0000000-0000-0000-0000-000000000001",
            "sla_hours": 4,
            "sla_deadline": now + timedelta(hours=2),
            "media": [
                ("PHOTO", "https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800", "Missing manhole cover on footpath", "SUBMISSION")
            ],
            "timeline": [
                ("REPORT_CREATED", "Emergency high-severity report created", "SUBMITTED", None),
                ("ROUTED", "Automatic Priority Escalation sent to Ward 130 Roads Inspector", "SUBMITTED", None)
            ],
            "custom_fields": '{"depth_meters": "2.5m", "near_school": true, "footpath_blocked": true}'
        },
        {
            "public_id": "CC-2026-0001845",
            "title": "Fallen Streetlight & Exposed Underground Cables",
            "description": "Streetlight pole #42 completely off for 4 consecutive nights. Dark corridor making night walking hazardous for women and elderly residents.",
            "status": "RESOLUTION_SUBMITTED",
            "priority": "HIGH",
            "severity": "HIGH",
            "category_id": "e0000000-0000-0000-0000-000000000003",
            "subcategory_id": "f0000000-0000-0000-0000-00000000e021",
            "lat": 13.0440,
            "lng": 80.2560,
            "address": "TTK Road, Alwarpet",
            "landmark": "Opposite Music Academy",
            "ward_id": "c0000000-0000-0000-0000-000000000124",
            "zone_id": "b0000000-0000-0000-0000-000000000009",
            "department_id": "d0000000-0000-0000-0000-000000000004",
            "assigned_to": "10000000-0000-0000-0000-000000000003",
            "assigned_team": "Electrical Lighting Squad 1",
            "sla_hours": 48,
            "sla_deadline": now + timedelta(hours=30),
            "resolved_at": now - timedelta(hours=2),
            "resolution_notes": "Replaced blown 120W LED fixture, repaired damaged insulated underground junction box, and restored illumination testing at 230V.",
            "resolution_before_photo": "https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=800",
            "resolution_after_photo": "https://images.unsplash.com/photo-1517816743773-6e0fd518b4a6?w=800",
            "media": [
                ("PHOTO", "https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=800", "Dark street lamp at night", "SUBMISSION"),
                ("PHOTO", "https://images.unsplash.com/photo-1517816743773-6e0fd518b4a6?w=800", "New LED luminaire fully lit and tested", "AFTER_WORK")
            ],
            "timeline": [
                ("REPORT_CREATED", "Report created by citizen", "SUBMITTED", None),
                ("ROUTED", "Routed to Electrical & Street Lighting Dept", "ROUTED", "SUBMITTED"),
                ("ACKNOWLEDGED", "Er. Balaji K approved work order", "ACKNOWLEDGED", "ROUTED"),
                ("WORK_STARTED", "Bucket truck and electrician on site", "IN_PROGRESS", "ACKNOWLEDGED"),
                ("RESOLUTION_SUBMITTED", "Fixture replaced. Ready for citizen verification.", "RESOLUTION_SUBMITTED", "IN_PROGRESS")
            ],
            "custom_fields": '{"pole_number": "TTK-LP-42", "completely_dark": true, "night_visibility_affected": true}'
        },
        {
            "public_id": "CC-2026-0001840",
            "title": "Severe Stormwater Drain Clog & Waterlogging",
            "description": "Silt and plastic waste clogged the culvert inlet causing 2-foot standing water across both traffic lanes after moderate rain.",
            "status": "RESOLVED",
            "priority": "HIGH",
            "severity": "HIGH",
            "category_id": "e0000000-0000-0000-0000-000000000004",
            "subcategory_id": "f0000000-0000-0000-0000-00000000e031",
            "lat": 13.0370,
            "lng": 80.2450,
            "address": "Eldams Road, Teynampet",
            "landmark": "Near SIET College Gate",
            "ward_id": "c0000000-0000-0000-0000-000000000114",
            "zone_id": "b0000000-0000-0000-0000-000000000009",
            "department_id": "d0000000-0000-0000-0000-000000000003",
            "sla_hours": 24,
            "resolution_notes": "Desilting machine operated, extracted 1.5 metric tonnes of sludge and plastic blockages. Flow restored smoothly to Buckingham canal.",
            "resolution_before_photo": "https://images.unsplash.com/photo-1547683905-f686c993aae5?w=800",
            "resolution_after_photo": "https://images.unsplash.com/photo-1517646287270-a5a9ca602e5c?w=800",
            "citizen_verified": True,
            "citizen_feedback": "Thank you GCC! The drain is completely clear and the water receded within hours of reporting.",
            "resolved_at": now - timedelta(days=1),
            "media": [
                ("PHOTO", "https://images.unsplash.com/photo-1547683905-f686c993aae5?w=800", "Flooded street before drain clearance", "BEFORE_WORK"),
                ("PHOTO", "https://images.unsplash.com/photo-1517646287270-a5a9ca602e5c?w=800", "Cleared culvert grating after work", "AFTER_WORK")
            ],
            "timeline": [
                ("REPORT_CREATED", "Report created", "SUBMITTED", None),
                ("ROUTED", "Routed to Drainage Dept", "ROUTED", "SUBMITTED"),
                ("ASSIGNED", "Super Sucker desilting unit assigned", "ASSIGNED", "ROUTED"),
                ("RESOLUTION_SUBMITTED", "Culvert cleared and water drained", "RESOLUTION_SUBMITTED", "IN_PROGRESS"),
                ("CITIZEN_VERIFIED", "Citizen verified fix: 'Yes, Fixed'", "RESOLVED", "RESOLUTION_SUBMITTED")
            ],
            "custom_fields": '{"water_depth": "60cm", "traffic_halted": true}'
        }
    ]

    for r in sample_reports:
        cur.execute("""
            INSERT INTO reports (
                public_id, user_id, is_anonymous, reporter_name, reporter_contact,
                category_id, subcategory_id, title, description, status, priority, severity,
                latitude, longitude, location, address, landmark,
                authority_id, department_id, zone_id, ward_id, assigned_to, assigned_team,
                custom_fields, sla_hours, sla_deadline, is_overdue,
                resolution_notes, resolution_before_photo, resolution_after_photo,
                citizen_verified, citizen_feedback, resolved_at, created_at, updated_at
            ) VALUES (
                %s, '10000000-0000-0000-0000-000000000001', FALSE, 'Revanth Citizen', '+919876543210',
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, ST_SetSRID(ST_MakePoint(%s, %s), 4326), %s, %s,
                'a0000000-0000-0000-0000-000000000001', %s, %s, %s, %s, %s,
                %s::jsonb, %s, %s, FALSE,
                %s, %s, %s,
                %s, %s, %s, NOW() - INTERVAL '2 days', NOW() - INTERVAL '1 day'
            ) RETURNING id;
        """, (
            r["public_id"], r["category_id"], r["subcategory_id"], r["title"], r["description"],
            r["status"], r["priority"], r["severity"],
            r["lat"], r["lng"], r["lng"], r["lat"], r["address"], r["landmark"],
            r["department_id"], r["zone_id"], r["ward_id"], r.get("assigned_to"), r.get("assigned_team"),
            r["custom_fields"], r["sla_hours"], r.get("sla_deadline"),
            r.get("resolution_notes"), r.get("resolution_before_photo"), r.get("resolution_after_photo"),
            r.get("citizen_verified"), r.get("citizen_feedback"), r.get("resolved_at")
        ))
        report_id = cur.fetchone()[0]

        # Insert media
        for m_type, m_url, m_caption, m_stage in r.get("media", []):
            cur.execute("""
                INSERT INTO report_media (report_id, media_type, url, caption, is_resolution_proof, stage)
                VALUES (%s, %s, %s, %s, %s, %s);
            """, (report_id, m_type, m_url, m_caption, m_stage in ("AFTER_WORK", "BEFORE_WORK"), m_stage))

        # Insert timeline
        for ev_type, ev_notes, ev_new_st, ev_old_st in r.get("timeline", []):
            cur.execute("""
                INSERT INTO report_timeline (report_id, actor_name, actor_role, event_type, old_status, new_status, notes)
                VALUES (%s, 'System Engine', 'SYSTEM', %s, %s, %s, %s);
            """, (report_id, ev_type, ev_old_st, ev_new_st, ev_notes))

    conn.commit()
    print("Seed data successfully inserted into Supabase!")
    cur.close()
    conn.close()

if __name__ == "__main__":
    seed()
