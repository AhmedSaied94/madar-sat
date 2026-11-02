import { z } from 'zod';

import { validation as copy } from '../i18n/ar';

// One Arabic error map for every schema the admin validates, Orval's generated ones included: a
// refusal never reaches the screen in English, and every editor shows the same wording for the same
// problem (constitution III, admin/CLAUDE.md "all copy in src/i18n/ar.ts").

z.setErrorMap((issue) => {
  switch (issue.code) {
    case z.ZodIssueCode.invalid_type:
      return { message: issue.received === 'undefined' || issue.received === 'null' ? copy.required : copy.invalid };
    case z.ZodIssueCode.too_small:
      return { message: issue.minimum === 1 && issue.type === 'string' ? copy.required : copy.invalid };
    case z.ZodIssueCode.too_big:
      return { message: copy.tooLong };
    case z.ZodIssueCode.invalid_string:
    case z.ZodIssueCode.invalid_enum_value:
    case z.ZodIssueCode.invalid_union:
    case z.ZodIssueCode.invalid_literal:
    case z.ZodIssueCode.not_finite:
      return { message: copy.invalid };
    // Our own messages (`.refine`, `.superRefine`) are already Arabic: keep them.
    default:
      return { message: issue.message ?? copy.invalid };
  }
});
