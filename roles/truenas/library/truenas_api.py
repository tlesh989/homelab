#!/usr/bin/python
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r"""
module: truenas_api
short_description: Make a single authenticated call to the TrueNAS websocket API
options:
  host:
    description: TrueNAS hostname or IP address.
    required: true
    type: str
  api_key:
    description: TrueNAS API key (from TRUENAS_API_KEY env var via Doppler).
    required: true
    type: str
    no_log: true
  method:
    description: Websocket API method (e.g. iscsi.portal.query).
    required: true
    type: str
  params:
    description: Positional parameters passed to the method call.
    type: list
    default: []
  validate_certs:
    description: Verify TLS certificate. Set false for self-signed certs.
    type: bool
    default: true
"""

from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            host=dict(type="str", required=True),
            api_key=dict(type="str", required=True, no_log=True),
            method=dict(type="str", required=True),
            params=dict(type="list", default=[]),
            validate_certs=dict(type="bool", default=True),
        ),
        supports_check_mode=True,
    )

    if module.check_mode:
        module.exit_json(changed=False, result={})

    host = module.params["host"]
    api_key = module.params["api_key"]
    method = module.params["method"]
    params = module.params["params"]
    validate_certs = module.params["validate_certs"]

    try:
        from truenas_api_client import Client
    except ImportError:
        module.fail_json(
            msg=(
                "truenas_api_client is required. "
                "Install: pip install 'truenas-api-client @ "
                "git+https://github.com/truenas/api_client.git@TS-25.10.3'"
            )
        )

    uri = f"wss://{host}/api/current"

    try:
        with Client(uri=uri, verify_ssl=validate_certs) as c:
            c.call('auth.login_with_api_key', api_key)
            result = c.call(method, *params)
    except Exception as e:
        module.fail_json(msg=f"TrueNAS API call '{method}' failed: {e}")

    module.exit_json(changed=False, result=result)


if __name__ == "__main__":
    main()
