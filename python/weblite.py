# Public Domain (-) 2008-2014 The Ampify Authors.
# See the Ampify UNLICENSE file for details.

"""A sexy micro-framework for use with Google App Engine."""

import logging
import os
import sys

from BaseHTTPServer import BaseHTTPRequestHandler
from cgi import FieldStorage
from datetime import datetime
from json import loads as json_decode
from os.path import dirname
from traceback import format_exception
from urllib import quote as urlquote, unquote as urlunquote
from urlparse import urljoin
from wsgiref.headers import Headers

from google.appengine.ext.blobstore import parse_blob_info
from google.appengine.runtime.apiproxy_errors import CapabilityDisabledError

# Extend the sys.path to include the parent and ``lib`` sibling directories.
sys.path.insert(0, dirname(__file__))
sys.path.insert(0, 'lib')

from tavutil.exception import html_format_exception

from webob import Request as WebObRequest # this import patches cgi.FieldStorage
                                          # to behave better for us too!

# ------------------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------------------

HTTP_STATUS_MESSAGES = BaseHTTPRequestHandler.responses

RESPONSE_NOT_IMPLEMENTED = ("501 Not Implemented", [])
RESPONSE_OPTIONS = (
    "200 OK",
    [("Allow:", "OPTIONS, GET, HEAD, POST")]
    )

RESPONSE_HEADERS_HTML = [
    ("Content-Type", "text/html; charset=utf-8")
]

STATUS_301 = "301 Moved Permanently"
STATUS_302 = "302 Found"

RESPONSE_403 = ("403 Forbidden", RESPONSE_HEADERS_HTML)
RESPONSE_404 = ("404 Not Found", RESPONSE_HEADERS_HTML)
RESPONSE_500 = ("500 Server Error", RESPONSE_HEADERS_HTML)
RESPONSE_503 = ("503 Service Unavailable", RESPONSE_HEADERS_HTML)

if os.environ.get('SERVER_SOFTWARE', '').startswith('Google'):
    RUNNING_ON_GOOGLE_SERVERS = True
else:
    RUNNING_ON_GOOGLE_SERVERS = False

HANDLERS = {}
SUPPORTED_HTTP_METHODS = frozenset(['GET', 'HEAD', 'POST'])

VALID_REQUEST_CONTENT_TYPES = frozenset([
    '', 'application/x-www-form-urlencoded', 'multipart/form-data'
    ])

# ------------------------------------------------------------------------------
# Error Messages
# ------------------------------------------------------------------------------

ERROR_404 = "Not Found"
ERROR_500_TRACEBACK = "Server Error: %s"
ERROR_503 = "Service Unavailable"

# ------------------------------------------------------------------------------
# Exceptions
# ------------------------------------------------------------------------------

# Handlers can throw exceptions to return specifc HTTP response codes.
#
# All the errors subclass the ``BaseHTTPError``.
class BaseHTTPError(Exception):
    pass

# The ``Redirect`` exception is used to handle HTTP 301/302 redirects.
class Redirect(BaseHTTPError):
    def __init__(self, uri, permanent=False):
        self.uri = urljoin('', str(uri))
        self.permanent = permanent

# The ``HTTPContent`` is used to return the associated content.
class HTTPContent(BaseHTTPError):
    def __init__(self, content):
        self.content = content

# The ``NotFound`` is used to represent the classic 404 error.
class NotFound(BaseHTTPError):
    pass

# The ``HTTPError`` is used to represent all other response codes.
class HTTPError(BaseHTTPError):
    def __init__(self, code=500):
        self.code = code

# ------------------------------------------------------------------------------
# Handler Utilities
# ------------------------------------------------------------------------------

HANDLER_DEFAULT_CONFIG = {
    'blob': False,
    'json': False
    }

# The ``handle`` decorator is used to turn a function into a handler.
def handle(name, renderers=[], **config):
    def __register_handler(function):
        __config = HANDLER_DEFAULT_CONFIG.copy()
        __config.update(config)
        for _name in name.split():
            HANDLERS[_name] = (function, renderers, __config)
        return function
    return __register_handler

# ------------------------------------------------------------------------------
# HTTP Utilities
# ------------------------------------------------------------------------------

# Return an HTTP header date/time string.
def get_http_datetime(timestamp=None):
    if timestamp:
        if not isinstance(timestamp, datetime):
            timestamp = datetime.fromtimestamp(timestamp)
    else:
        timestamp = datetime.utcnow()
    return timestamp.strftime('%a, %d %B %Y %H:%M:%S GMT') # %m

# ------------------------------------------------------------------------------
# Context
# ------------------------------------------------------------------------------

# The ``Context`` class encompasses the HTTP request/response. An instance,
# specific to the current request, is passed in as the first parameter to all
# handlers.
class Context(object):

    NotFound = NotFound
    Redirect = Redirect

    urlquote = staticmethod(urlquote)
    urlunquote = staticmethod(urlunquote)

    ajax_request = None
    json_callback = None
    end_pipeline = None
    site_host = None

    def __init__(self, environ, ssl_mode):
        self.environ = environ
        self.host = environ['HTTP_HOST']
        self._status = (200, 'OK')
        self._raw_headers = []
        self.response_headers = Headers(self._raw_headers)
        self.ssl_mode = ssl_mode
        if ssl_mode:
            self.scheme = 'https'
        else:
            self.scheme = 'http'

    def set_response_status(self, code, message=None):
        if not message:
            message = HTTP_STATUS_MESSAGES.get(code, ["Server Error"])[0]
        self._status = (code, message)

    def cache_response(self, duration=864000):
        self.response_headers['Pragma'] = "Public"
        self.response_headers['Cache-Control'] = "public, max-age=%d;" % duration

    def do_not_cache_response(self):
        headers = self.response_headers
        headers['Expires'] = "Fri, 31 December 1999 23:59:59 GMT"
        headers['Last-Modified'] = get_http_datetime()
        headers['Cache-Control'] = "no-cache, must-revalidate" # HTTP/1.1
        headers['Pragma'] =  "no-cache"                        # HTTP/1.0

    def compute_url(self, *args, **kwargs):
        return self.compute_url_for_host(self.site_host or self.host, *args, **kwargs)

    def compute_url_for_host(self, host, *args, **kwargs):
        out = self.scheme + '://' + host + '/' + '/'.join(
            arg.encode('utf-8') for arg in args
            )
        if kwargs:
            out += '?'
            _set = 0
            _l = ''
            for key, value in kwargs.items():
                key = urlquote(key).replace(' ', '+')
                if value is None:
                    value = ''
                if isinstance(value, list):
                    for val in value:
                        if _set: _l = '&'
                        out += '%s%s=%s' % (
                            _l, key,
                            urlquote(val.encode('utf-8')).replace(' ', '+')
                            )
                        _set = 1
                else:
                    if _set: _l = '&'
                    out += '%s%s=%s' % (
                        _l, key, urlquote(value.encode('utf-8')).replace(' ', '+')
                        )
                    _set = 1
        return out

    @property
    def site_url(self):
        if not hasattr(self, '_site_url'):
            if self.site_host:
                self._site_url = self.scheme + '://' + self.site_host
            else:
                self._site_url = self.scheme + '://' + self.host
        return self._site_url

    @property
    def url(self):
        if not hasattr(self, '_url'):
            self._url = self.site_url + self.environ['PATH_INFO']
        return self._url

    @property
    def url_with_qs(self):
        if not hasattr(self, '_url_with_qs'):
            env = self.environ
            query = env['QUERY_STRING']
            self._url_with_qs = (
                self.site_url + env['PATH_INFO'] + (
                    query and '?' or '') + query
                )
        return self._url_with_qs

# ------------------------------------------------------------------------------
# App Runner
# ------------------------------------------------------------------------------

def handle_http_request(
    env, start_response, dict=dict, isinstance=isinstance, urlunquote=urlunquote,
    unicode=unicode, get_response_headers=lambda: None
    ):

    try:

        http_method = env['REQUEST_METHOD']
        ssl_mode = env['wsgi.url_scheme'] == 'https'

        if http_method == 'OPTIONS':
            start_response(*RESPONSE_OPTIONS)
            return []

        if http_method not in SUPPORTED_HTTP_METHODS:
            start_response(*RESPONSE_NOT_IMPLEMENTED)
            return []

        _path_info = env['PATH_INFO']
        if isinstance(_path_info, unicode):
            _args = [arg for arg in _path_info.split(u'/') if arg]
        else:
            _args = [
                unicode(arg, 'utf-8', 'strict')
                for arg in _path_info.split('/') if arg
                ]

        kwargs = {}
        for part in [
            sub_part
            for part in env['QUERY_STRING'].lstrip('?').split('&')
            for sub_part in part.split(';')
            ]:
            if not part:
                continue
            part = part.split('=', 1)
            if len(part) == 1:
                value = None
            else:
                value = part[1]
            key = urlunquote(part[0].replace('+', ' '))
            if value:
                value = unicode(
                    urlunquote(value.replace('+', ' ')), 'utf-8', 'strict'
                    )
            else:
                value = None
            if key in kwargs:
                _val = kwargs[key]
                if isinstance(_val, list):
                    _val.append(value)
                else:
                    kwargs[key] = [_val, value]
                continue
            kwargs[key] = value

        ctx = Context(env, ssl_mode)

        if _args:
            name = _args[0]
            args = _args[1:]
        else:
            name = '/'
            args = ()

        if name not in HANDLERS:
            logging.error("Handler not found: %s" % name)
            raise NotFound

        handler, renderers, config = HANDLERS[name]
        json = config['json']

        # Parse the POST body if it exists and is of a known content type.
        if http_method == 'POST':

            content_type = env.get('CONTENT-TYPE', '')
            if not content_type:
                content_type = env.get('CONTENT_TYPE', '')

            if ';' in content_type:
                content_type = content_type.split(';', 1)[0]

            if json or content_type == 'application/json':

                payload = json_decode(env['wsgi.input'].read())
                if json and not (json is True):
                    kwargs[json] = payload
                else:
                    kwargs.update(payload)

            elif content_type in VALID_REQUEST_CONTENT_TYPES:

                post_environ = env.copy()
                post_environ['QUERY_STRING'] = ''

                post_data = FieldStorage(
                    environ=post_environ, fp=env['wsgi.input'],
                    keep_blank_values=True
                    ).list or []

                for field in post_data:
                    key = field.name
                    if field.filename:
                        if config['blob']:
                            value = parse_blob_info(field)
                        else:
                            value = field
                    else:
                        value = unicode(field.value, 'utf-8', 'strict')
                    if key in kwargs:
                        _val = kwargs[key]
                        if isinstance(_val, list):
                            _val.append(value)
                        else:
                            kwargs[key] = [_val, value]
                        continue
                    kwargs[key] = value

        def get_response_headers():
            str_headers = []; new_header = str_headers.append
            for k, v in ctx._raw_headers:
                if isinstance(k, unicode):
                    k = k.encode('utf-8')
                if isinstance(v, unicode):
                    v = v.encode('utf-8')
                new_header((k, v))
            return str_headers

        if 'submit' in kwargs:
            del kwargs['submit']

        if 'callback' in kwargs:
            ctx.json_callback = kwargs.pop('callback')

        if env.get('HTTP_X_REQUESTED_WITH') == 'XMLHttpRequest':
            ctx.ajax_request = 1

        if RUNNING_ON_GOOGLE_SERVERS and not ssl_mode:
            raise NotFound

        # Try and respond with the result of calling the handler.
        content = handler(ctx, *args, **kwargs)

        for renderer in renderers:
            if ctx.end_pipeline:
                break
            if content is None:
                content = {
                    'content': ''
                }
            elif not isinstance(content, dict):
                content = {
                    'content': content
                    }
            content = renderer(ctx, **content)

        if content is None:
            content = ''
        elif isinstance(content, unicode):
            content = content.encode('utf-8')

        raise HTTPContent(content)

    # Return the content.
    except HTTPContent, payload:

        content = payload.content
        if 'Content-Type' not in ctx.response_headers:
            ctx.response_headers['Content-Type'] = 'text/html; charset=utf-8'

        ctx.response_headers['Content-Length'] = str(len(content))

        start_response(('%d %s\r\n' % ctx._status), get_response_headers())
        if http_method == 'HEAD':
            return []

        return [content]

    # Handle 404s.
    except NotFound:
        start_response(*RESPONSE_404)
        return [ERROR_404]

    # Handle HTTP 301/302 redirects.
    except Redirect, redirect:
        headers = get_response_headers()
        if not headers:
            headers = []
        headers += [("Content-Type", "text/html; charset=utf-8")]
        headers.append(("Location", redirect.uri))
        if redirect.permanent:
            start_response(STATUS_301, headers)
        else:
            start_response(STATUS_302, headers)
        return []

    # Handle other HTTP response codes.
    except HTTPError, error:
        start_response(("%s %s" % (error.code, HTTP_STATUS_MESSAGES[error.code])), [])
        return []

    except CapabilityDisabledError:
        start_response(*RESPONSE_503)
        return [ERROR_503]

    # Log any errors and return an HTTP 500 response.
    except Exception, error:
        logging.critical(''.join(format_exception(*sys.exc_info())))
        if RUNNING_ON_GOOGLE_SERVERS:
            traceback = escape("%s: %s" % (error.__class__.__name__, error))
        else:
            traceback = ''.join(html_format_exception())
        response = ERROR_500_TRACEBACK % traceback
        start_response(*RESPONSE_500)
        if isinstance(response, unicode):
            response = response.encode('utf-8')
        return [response]

# ------------------------------------------------------------------------------
# HTML Escape
# ------------------------------------------------------------------------------

def escape(s):
    return s.replace(u"&", u"&amp;").replace(u"<", u"&lt;").replace(
        u">", u"&gt;").replace(u'"', u"&quot;")

# ------------------------------------------------------------------------------
# WSGI App Alias
# ------------------------------------------------------------------------------

app = handle_http_request
