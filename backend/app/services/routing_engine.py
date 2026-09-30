from typing import Dict, Any, Optional
from backend.app.core.database import get_db

def route_civic_issue(category_id: str, subcategory_id: Optional[str], ward_id: Optional[str]) -> Dict[str, Any]:
    """Database-driven routing engine: category + ward -> department + SLA."""
    with get_db() as cur:
        # Check specific routing rule for category & ward
        cur.execute("""
            SELECT r.department_id, d.name as department_name, d.code as department_code, d.email as department_email
            FROM routing_rules r
            JOIN departments d ON r.department_id = d.id
            WHERE r.category_id = %s AND (r.ward_id = %s OR r.ward_id IS NULL) AND r.active = TRUE
            ORDER BY r.ward_id NULLS LAST, r.priority ASC
            LIMIT 1;
        """, (category_id, ward_id))
        dept_match = cur.fetchone()
        
        # Check subcategory SLA and priority if provided
        sub_sla = 48
        priority = "MEDIUM"
        if subcategory_id:
            cur.execute("""
                SELECT sla_hours, priority_level
                FROM subcategories
                WHERE id = %s;
            """, (subcategory_id,))
            sub_res = cur.fetchone()
            if sub_res:
                sub_sla = sub_res["sla_hours"]
                priority = sub_res["priority_level"]
        else:
            cur.execute("""
                SELECT default_sla_hours
                FROM categories
                WHERE id = %s;
            """, (category_id,))
            cat_res = cur.fetchone()
            if cat_res:
                sub_sla = cat_res["default_sla_hours"]
                
        if dept_match:
            return {
                "department_id": str(dept_match["department_id"]),
                "department_name": dept_match["department_name"],
                "department_code": dept_match["department_code"],
                "department_email": dept_match["department_email"],
                "sla_hours": sub_sla,
                "priority": priority
            }
            
        # Fallback to general roads department
        return {
            "department_id": "d0000000-0000-0000-0000-000000000001",
            "department_name": "Roads & Bridges Department",
            "department_code": "roads",
            "department_email": "roads.gcc@chennaicorporation.gov.in",
            "sla_hours": sub_sla,
            "priority": priority
        }
