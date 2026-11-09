#!/usr/bin/env python3
"""Check observed AX names/help and preserve GUI state/layout/focus contracts."""
from pathlib import Path
import argparse,hashlib,json,re
ROOT=Path(__file__).resolve().parents[4]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--current',type=Path,required=True);p.add_argument('--action',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
    records=[json.loads((folder/'run.json').read_text()) for folder in [a.baseline,a.current,a.action]]
    assert all(r['exit']==0 and r['owned_process_terminal'] and r['temporary_project_removed'] and r['isolated_save_removed'] for r in records)
    before,after,action=records
    changed={k for k,v in before['product_sha256'].items() if v!=after['product_sha256'][k]}
    assert changed=={'scripts/features/cards.gd','scripts/features/perks.gd','scripts/features/ui_shell.gd','scripts/features/menu.gd','scripts/float_panel.gd'},changed
    assert after['product_sha256']==action['product_sha256']
    assert all(sha(ROOT/k)==v for k,v in after['product_sha256'].items())
    old=json.loads((a.baseline/'observations.json').read_text());new=json.loads((a.current/'observations.json').read_text());assert len(old)==len(new)==8
    states=[]
    for b,c in zip(old,new):
        assert b['label']==c['label'] and b['before']==c['before'] and b['after']==c['after'],c['label']
        fields=['class','text','disabled','focus_mode','rect','custom_draw','tooltip']
        assert [[x[k] for k in fields] for x in b['controls']]==[[x[k] for k in fields] for x in c['controls']],c['label']
        states.append({'label':c['label'],'game_state_equal':True,'visible_control_rect_text_focus_disabled_tooltip_equal':True,'controls':len(c['controls'])})
    selected={}
    for label in ['choose','inspector','pause','perk']:
        snapshots=[json.loads((folder/(label+'-ax.json')).read_text()) for folder in [a.baseline,a.current]]
        buttons=[[r for r in d['rows'] if r.get('AXRole')=='AXButton' and r.get('AXSubrole')=='AXUnknown'] for d in snapshots]
        assert all(r.get('attribute_errors',{}).get('AXTitle')!=-25204 for values in buttons for r in values),'CannotComplete is not an empty accessible name'
        blank=[sum(not r.get('AXTitle') and not r.get('AXDescription') for r in values) for values in buttons]
        assert blank[1]==0,(label,blank)
        selected[label]={'before_blank_as_returned':blank[0],'after_blank_as_returned':blank[1],'buttons_before':len(buttons[0]),'buttons_after':len(buttons[1])}
        if label in ['choose','perk']:
            for name in [c['name'] for s in new if s['label']==label for c in s['controls'] if c['name'].startswith('카드 ')]:
                found=[r for r in buttons[1] if r.get('AXTitle')==name]
                assert len(found)==1 and found[0].get('AXHelp') and 'AXPress' in found[0]['actions'],(label,name)
        if label=='pause':
            assert all(any(r.get('AXTitle')==name for r in buttons[1]) for name in ['계속','튜토리얼','처음부터','판 끝내기','시작 화면','끄기'])
    assert action['AXPress_card_held_without_consumption']
    result={'verdict':'selected_names_actions_verified; whole_accessibility_HOLD','changed_product_scripts':sorted(changed),'product_sha256':after['product_sha256'],'states':states,'selected_AX':selected,'actual_AXPress_card_held_without_consumption':True,'input_focus_camera_policy_changed':False,'sources':[{'path':str(folder),'run_sha256':sha(folder/'run.json')} for folder in [a.baseline,a.current,a.action]],'limits':['AXChildren is a raw hierarchy, not VoiceOver linear navigation or visible-child proof. Later dumps include controls hidden in the current GUI inventory; do not count them as current visible UI or claim complete tree freshness.','Window title marker proves owned window/state; not every descendant update.','No VoiceOver speech, switch, iOS/Android provider or physical/human task pass.','Names/help and one AXPress journey only, not all field actions/keyboard/contrast.']}
    a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('UI-54 selected AX names/help/press and8GUI state/layout/focus comparisons verified; whole HOLD')
if __name__=='__main__':main()
