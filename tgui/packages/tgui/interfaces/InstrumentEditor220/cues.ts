export type Cue = { time: number; text: string };

export function validateCues(cues: Cue[], length: number) {
  if (
    cues.length > 200 ||
    cues.some(
      (cue) =>
        !cue ||
        !Number.isFinite(cue.time) ||
        cue.time < 0 ||
        cue.time > length ||
        typeof cue.text !== 'string' ||
        Array.from(cue.text).length > 300,
    )
  ) {
    throw new Error(
      'Maximum 200 cues, 300 characters per line; all times must fit the OGG.',
    );
  }
}

/** Move the edited cue and everything after it by the same delta. */
export function rippleCueTime<T extends Cue>(
  cues: T[],
  index: number,
  time: number,
  length: number,
): T[] {
  if (
    !cues[index] ||
    !Number.isFinite(time) ||
    time < (cues[index - 1]?.time ?? 0)
  )
    throw new Error('Cue time must not precede the previous line.');
  const delta = time - cues[index].time;
  const result = cues.map((cue, i) =>
    i >= index
      ? { ...cue, time: Math.round((cue.time + delta) * 1000) / 1000 }
      : cue,
  );
  validateCues(result, length);
  return result;
}

export function validateCueInterval(interval: number) {
  if (!Number.isFinite(interval) || interval < 0.1 || interval > 120)
    throw new Error('Interval must be between 0.1 and 120 seconds.');
}

/** Apply one delta to the selection, or to every cue when nothing is selected. */
export function shiftCues<T extends Cue & { selected: boolean }>(
  cues: T[],
  delta: number,
  length: number,
): T[] {
  if (!Number.isFinite(delta)) throw new Error('Invalid time shift.');
  const selected = cues.some((cue) => cue.selected);
  const result = cues
    .map((cue) =>
      selected && !cue.selected
        ? cue
        : { ...cue, time: Math.round((cue.time + delta) * 1000) / 1000 },
    )
    .sort((a, b) => a.time - b.time);
  validateCues(result, length);
  return result;
}

export function appendCueText(
  cues: Cue[],
  text: string,
  interval: number,
  length: number,
): Cue[] {
  validateCueInterval(interval);
  const lines = text
    .split(/\r\n|\n|\r/)
    .map((line) => line.trim())
    .filter(Boolean);
  const start = cues.length ? cues[cues.length - 1].time + interval : 0;
  const added = lines.map((line, i) => ({
    time: Math.round((start + i * interval) * 1000) / 1000,
    text: line,
  }));
  validateCues([...cues, ...added], length);
  return added;
}
