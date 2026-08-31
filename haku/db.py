"""
db.py — Persistencia con SQLAlchemy + SQLite.

Modelos Video y Shot. Usamos SQLAlchemy para que migrar a Postgres más adelante
sea solo cambiar HAKU_DB_URL (ver config.py), sin reescribir consultas.

El index.json es el artefacto de una corrida; SQLite es la memoria persistente
de qué videos y shots existen (la usa la UI para listar y recargar sin recomputar).
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    create_engine,
    select,
)
from sqlalchemy.orm import (
    DeclarativeBase,
    Mapped,
    Session,
    mapped_column,
    relationship,
)

from . import config


class Base(DeclarativeBase):
    pass


class Video(Base):
    __tablename__ = "videos"

    id: Mapped[str] = mapped_column(String, primary_key=True)  # slug estable
    path: Mapped[str] = mapped_column(String, nullable=False)
    filename: Mapped[str] = mapped_column(String, nullable=False)
    fps: Mapped[float] = mapped_column(Float, nullable=False)
    frame_count: Mapped[int] = mapped_column(Integer, nullable=False)
    width: Mapped[int] = mapped_column(Integer, default=0)
    height: Mapped[int] = mapped_column(Integer, default=0)
    duration_s: Mapped[float] = mapped_column(Float, default=0.0)
    created_at: Mapped[str] = mapped_column(
        String, default=lambda: datetime.now(timezone.utc).isoformat()
    )

    shots: Mapped[list["Shot"]] = relationship(
        back_populates="video",
        cascade="all, delete-orphan",
        order_by="Shot.shot_index",
    )


class Shot(Base):
    __tablename__ = "shots"
    __table_args__ = (UniqueConstraint("video_id", "shot_index", name="uq_video_shot"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    video_id: Mapped[str] = mapped_column(ForeignKey("videos.id"), index=True)
    shot_index: Mapped[int] = mapped_column(Integer, nullable=False)
    shot_id: Mapped[str] = mapped_column(String, nullable=False)  # p.ej. "shot_0001"

    in_frame: Mapped[int] = mapped_column(Integer, nullable=False)
    out_frame: Mapped[int] = mapped_column(Integer, nullable=False)
    in_tc: Mapped[str] = mapped_column(String, nullable=False)
    out_tc: Mapped[str] = mapped_column(String, nullable=False)

    brightness: Mapped[float] = mapped_column(Float, default=0.0)
    saturation: Mapped[float] = mapped_column(Float, default=0.0)
    motion: Mapped[float] = mapped_column(Float, default=0.0)
    duration_s: Mapped[float] = mapped_column(Float, default=0.0)
    transcript: Mapped[str] = mapped_column(Text, default="")

    video: Mapped[Video] = relationship(back_populates="shots")


# Engine único del proceso. check_same_thread=False para que FastAPI (varios
# hilos) pueda usar SQLite sin quejarse.
_connect_args = {"check_same_thread": False} if config.DB_URL.startswith("sqlite") else {}
engine = create_engine(config.DB_URL, connect_args=_connect_args)


def init_db() -> None:
    config.ensure_dirs()
    Base.metadata.create_all(engine)


def save_index(video_meta: dict, shots: list[dict]) -> None:
    """Guarda (o reemplaza) un video y todos sus shots de forma idempotente."""
    init_db()
    with Session(engine) as session:
        existing = session.get(Video, video_meta["id"])
        if existing is not None:
            session.delete(existing)  # cascade borra los shots viejos
            session.flush()

        video = Video(
            id=video_meta["id"],
            path=video_meta["path"],
            filename=video_meta["filename"],
            fps=video_meta["fps"],
            frame_count=video_meta["frame_count"],
            width=video_meta.get("width", 0),
            height=video_meta.get("height", 0),
            duration_s=video_meta.get("duration_s", 0.0),
        )
        for i, s in enumerate(shots):
            video.shots.append(
                Shot(
                    shot_index=i,
                    shot_id=s["shot_id"],
                    in_frame=s["in_frame"],
                    out_frame=s["out_frame"],
                    in_tc=s["in_tc"],
                    out_tc=s["out_tc"],
                    brightness=s.get("brightness", 0.0),
                    saturation=s.get("saturation", 0.0),
                    motion=s.get("motion", 0.0),
                    duration_s=s.get("duration_s", 0.0),
                    transcript=s.get("transcript", ""),
                )
            )
        session.add(video)
        session.commit()


def list_videos() -> list[dict]:
    init_db()
    with Session(engine) as session:
        rows = session.scalars(select(Video).order_by(Video.created_at.desc())).all()
        return [
            {
                "id": v.id,
                "filename": v.filename,
                "path": v.path,
                "fps": v.fps,
                "frame_count": v.frame_count,
                "duration_s": v.duration_s,
                "n_shots": len(v.shots),
            }
            for v in rows
        ]


def get_video(video_id: str) -> dict | None:
    init_db()
    with Session(engine) as session:
        v = session.get(Video, video_id)
        if v is None:
            return None
        return {
            "id": v.id,
            "filename": v.filename,
            "path": v.path,
            "fps": v.fps,
            "frame_count": v.frame_count,
            "width": v.width,
            "height": v.height,
            "duration_s": v.duration_s,
        }
