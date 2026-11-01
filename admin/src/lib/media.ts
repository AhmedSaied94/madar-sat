import { uploadMedia } from '../api/generated/admin';
import type { MediaAsset } from '../api/generated/admin.schemas';
import { ApiError, INVALID_RESPONSE } from '../api/http';

// One door to POST /admin/api/media: the editor uploads the file, then saves the asset id on the
// record, so a lost save never leaves a half-written row.

export async function uploadAsset(file: File, kind: 'image' | 'audio'): Promise<MediaAsset> {
  // Orval types the multipart `file` part as a string; at runtime the File goes straight into the
  // FormData it builds, which is what axios sends.
  const response = await uploadMedia({ file: file as unknown as string, kind });
  if (!response.data) throw new ApiError(INVALID_RESPONSE, 200);
  return response.data;
}
