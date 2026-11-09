"""Experimental event servicing between existing steps; never edits the checkout."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[5]
BASELINE = '524286d3ea29599a463a69bdad62f1658dec2e09'


def frozen(path):
    return subprocess.check_output(['git', 'show', BASELINE + ':' + path], cwd=ROOT, text=True)


def transform(source):
    marker = 'func _process(delta: float) -> void:\n'
    assert source.count(marker) == 1
    source = source.replace(marker, 'var _qa_batch_running := false\n' + marker + '\tif _qa_batch_running:\n\t\treturn\n', 1)
    before = '''\tfor i in steps:
\t\tsession.combat_system._sim_step(dt)
\t\tif session.phase != BinduSession.Phase.WAVE:
\t\t\tbreak
'''
    after = '''\t_qa_batch_running = true
\t_qa_simulate_batch(session, steps, dt)
\t_qa_batch_running = false

func _qa_simulate_batch(s: BinduSession, steps: int, dt: float) -> void:
\tvar speed := s.game_speed
\tvar factor := s.abilities_system.skill_speed_factor()
\tvar run := s.run_id
\tvar wave := s.wave
\tfor i in steps:
\t\ts.combat_system._sim_step(dt)
\t\tif s.phase != BinduSession.Phase.WAVE or i + 1 == steps:
\t\t\treturn
\t\tDisplayServer.process_events()
\t\t# A dispatched callback can synchronously remove/free the session.
\t\tif not is_instance_valid(s) or s.is_queued_for_deletion() or not s.is_inside_tree():
\t\t\treturn
\t\tif s.get_tree().paused or s.title_label.visible or s.phase != BinduSession.Phase.WAVE or s.run_id != run or s.wave != wave:
\t\t\treturn
\t\tif s.help_label.visible or s.settings_panel.visible or s.records_panel.visible or s.notes_panel.visible:
\t\t\treturn
\t\tif s.game_speed != speed or s.abilities_system.skill_speed_factor() != factor:
\t\t\treturn
'''
    assert source.count(before) == 1
    return source.replace(before, after, 1)
