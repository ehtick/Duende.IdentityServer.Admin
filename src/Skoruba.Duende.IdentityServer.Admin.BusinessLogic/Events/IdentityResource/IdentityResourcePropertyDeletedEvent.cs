// Copyright (c) Jan Škoruba. All Rights Reserved.
// Licensed under the Apache License, Version 2.0.

using Skoruba.AuditLogging.Events;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Dtos.Configuration;
using Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Helpers;

namespace Skoruba.Duende.IdentityServer.Admin.BusinessLogic.Events.IdentityResource
{
    public class IdentityResourcePropertyDeletedEvent : AuditEvent
    {
        public IdentityResourcePropertiesDto IdentityResourceProperty { get; set; }

        public IdentityResourcePropertyDeletedEvent(IdentityResourcePropertiesDto identityResourceProperty)
        {
            IdentityResourceProperty = AuditEventDataSanitizer.Sanitize(identityResourceProperty);
        }
    }
}
