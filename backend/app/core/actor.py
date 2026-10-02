from dataclasses import dataclass
from typing import Optional
from urllib.parse import unquote
from fastapi import Header, HTTPException

# The app sends its short role codes; the database stores the long ones.
ROLE_ALIASES = {
    "CITIZEN": "CITIZEN",
    "OFFICER": "DEPARTMENT_OFFICER",
    "DEPARTMENT_OFFICER": "DEPARTMENT_OFFICER",
    "FIELD_WORKER": "FIELD_WORKER",
    "ADMIN": "SUPER_ADMIN",
    "SUPER_ADMIN": "SUPER_ADMIN",
}

STAFF_ROLES = ("DEPARTMENT_OFFICER", "SUPER_ADMIN")


@dataclass
class Actor:
    user_id: Optional[str]
    role: str
    name: str


def get_actor(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_name: Optional[str] = Header(None),
) -> Actor:
    """Identify the caller from the X-User-* headers sent by the mobile app."""
    role = ROLE_ALIASES.get((x_user_role or "").upper())
    if not role:
        raise HTTPException(status_code=401, detail="Missing or unknown X-User-Role header.")
    name = unquote(x_user_name).strip() if x_user_name else ""
    return Actor(user_id=x_user_id or None, role=role, name=name or role.replace("_", " ").title())


def require_role(actor: Actor, *roles: str) -> None:
    if actor.role not in roles:
        raise HTTPException(
            status_code=403,
            detail=f"Role {actor.role} is not allowed to perform this action.",
        )
