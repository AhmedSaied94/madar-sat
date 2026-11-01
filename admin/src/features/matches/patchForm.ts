import { zodResolver } from '@hookform/resolvers/zod';
import { useForm, type Resolver } from 'react-hook-form';

import { createMatchBody, patchMatchBody } from '../../api/generated/admin.zod';
import type { MatchCreate, MatchPatch } from '../../api/generated/admin.schemas';

// A4's one form (A-F1): the patch and the create body are checked by Orval's Zod schemas, the same
// ones the client uses on the wire, so what the editor accepts is what the API accepts. The fields
// themselves stay the editor's own controlled inputs; React Hook Form owns the validation.

export function useMatchForm() {
  const patchForm = useForm<MatchPatch>({
    resolver: zodResolver(patchMatchBody) as Resolver<MatchPatch>,
    defaultValues: {},
  });
  const createForm = useForm<MatchCreate>({
    resolver: zodResolver(createMatchBody) as Resolver<MatchCreate>,
    defaultValues: {},
  });

  /** True when the assembled patch passes the API's schema; the field errors stay on the form. */
  const validatePatch = async (patch: MatchPatch): Promise<boolean> => {
    patchForm.reset(patch, { keepDefaultValues: true });
    return patchForm.trigger();
  };

  const validateCreate = async (body: MatchCreate): Promise<boolean> => {
    createForm.reset(body, { keepDefaultValues: true });
    return createForm.trigger();
  };

  return { patchForm, createForm, validatePatch, validateCreate };
}
