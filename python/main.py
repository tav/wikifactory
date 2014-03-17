# Public Domain (-) 2014 The Wikifactory Authors.
# See the Wikifactory UNLICENSE file for details.

from json import dumps as encode_json
from secret import APP_ID, TOKEN
from weblite import app, handle, RUNNING_ON_GOOGLE_SERVERS

from pygments import highlight
from pygments.formatters import HtmlFormatter
from pygments.lexers import get_lexer_by_name, TextLexer

from tavutil.crypto import secure_string_comparison

# -----------------------------------------------------------------------------
# Globals
# -----------------------------------------------------------------------------

SERVICES = {}

PARAM_NONE = 0
PARAM_SINGLE = 1
PARAM_SPLAT = 2

# -----------------------------------------------------------------------------
# Service Handler
# -----------------------------------------------------------------------------

@handle('service', json='data')
def service_handler(ctx, method, token, data):
    # Check that the X-Appengine-Inbound-Appid header matches.
    if RUNNING_ON_GOOGLE_SERVERS:
        if ctx.environ.get('HTTP_X_APPENGINE_INBOUND_APPID') != APP_ID:
            raise ctx.NotFound
    # Check that the shared secret token matches.
    if not secure_string_comparison(token, TOKEN):
        raise ctx.NotFound
    ctx.response_headers['Content-Type'] = 'application/json'
    try:
        handler, param = SERVICES[method]
        if param == PARAM_SPLAT:
            reply = handler(ctx, **data)
        elif param == PARAM_SINGLE:
            reply = handler(ctx, data)
        else:
            reply = handler(ctx)
        return encode_json({'reply': reply})
    except Exception, err:
        return encode_json({'error':
            {'type': err.__class__.__name__, 'message': str(err)}
            })

# -----------------------------------------------------------------------------
# Service Decorator
# -----------------------------------------------------------------------------

def service(param=PARAM_SPLAT):
    def __register(handler):
        name = handler.__name__.replace('_', '.')
        SERVICES[name] = (handler, param)
        return handler
    return __register

# -----------------------------------------------------------------------------
# Services
# -----------------------------------------------------------------------------

@service()
def syntax_highlight(ctx, text, lang=None):
    if lang:
        try:
            lexer = get_lexer_by_name(lang)
        except ValueError:
            lang = 'txt'
            lexer = TextLexer()
    else:
        lang = 'txt'
        lexer = TextLexer()
    formatter = HtmlFormatter(
        cssclass='syntax %s' % lang, lineseparator='<br/>'
        )
    return highlight(text, lexer, formatter)
