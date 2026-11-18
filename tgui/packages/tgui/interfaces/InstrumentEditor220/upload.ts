export type PlayAction = 'play_music';
export type MusicUploadStatus = {
  id: string;
  next: number;
  state: 'receiving' | 'complete' | 'error';
  error?: string;
};

// Each action stays below TGUI's default 32-chunk limit, including escaping.
export function splitMusicDocument(document: object): string[] {
  const text = JSON.stringify(document);
  if (text.length > 600000) throw new Error('Music project exceeds 600 KB.');
  const parts: string[] = [];
  let part = '';
  let size = 0;
  for (const character of text) {
    const encoded = encodeURIComponent(
      JSON.stringify(character).slice(1, -1),
    ).length;
    if (size + encoded > 8192) {
      parts.push(part);
      part = '';
      size = 0;
    }
    part += character;
    size += encoded;
  }
  if (part) parts.push(part);
  return parts;
}
