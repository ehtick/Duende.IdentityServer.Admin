// Copyright (c) Jan Škoruba. All Rights Reserved.
// Licensed under the Apache License, Version 2.0.

using Skoruba.AuditLogging.Events;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Identity.Dtos.Grant;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Identity.Helpers;

namespace Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Identity.Events.PersistedGrant
{
    public class PersistedGrantsIdentityByUserRequestedEvent : AuditEvent
    {
        public PersistedGrantsDto PersistedGrants { get; set; }

        public PersistedGrantsIdentityByUserRequestedEvent(PersistedGrantsDto persistedGrants)
        {
            PersistedGrants = AuditEventDataSanitizer.Sanitize(persistedGrants);
        }
    }
}
