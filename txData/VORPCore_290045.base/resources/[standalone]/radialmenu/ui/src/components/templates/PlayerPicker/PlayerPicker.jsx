import React from 'react';
import { useTranslation } from '../../../i18n';
import styles from './PlayerPicker.module.css';

// On-screen player picker (slots with target = 'cursor'). Lua streams the
// screen position of every player in range (nui:picker:update, x / y in
// 0..1); one clickable name tag floats over each head. Click a tag = pick,
// anything else (backdrop click, right click, Esc handled in App) = cancel.
// picker = { players: [{ serverId, name, x, y, visible }] }
export default function PlayerPicker({ picker, onSelect, onCancel }) {
  const { t } = useTranslation();
  const players = (picker?.players || []).filter((p) => p.visible);

  const cancel = (e) => {
    e.preventDefault();
    onCancel();
  };

  return (
    <div className={styles.layer} onClick={cancel} onContextMenu={cancel}>
      {players.map((p) => (
        <button
          key={p.serverId}
          type="button"
          className={styles.tag}
          style={{ left: `${p.x * 100}%`, top: `${p.y * 100}%` }}
          onClick={(e) => { e.stopPropagation(); onSelect(p.serverId); }}
          onContextMenu={cancel}
        >
          <span className={styles.name}>{p.name}</span>
          <span className={styles.pin} />
        </button>
      ))}

      <div className={styles.hint}>
        <span className={styles.hintMain}>{players.length ? t('picker.hint') : t('picker.empty')}</span>
        <span className={styles.hintSep}>·</span>
        <span className={styles.hintSub}>{t('picker.cancel')}</span>
      </div>
    </div>
  );
}
