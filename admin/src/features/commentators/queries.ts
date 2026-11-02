import { useListCommentators } from '../../api/generated/admin';
import type { ListCommentatorsParams } from '../../api/generated/admin.schemas';

// A10's read: the commentator list with its search.

export function useCommentators(params: ListCommentatorsParams) {
  return useListCommentators(params);
}
