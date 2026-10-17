import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
import httpx

from routers import app_version as versions


def release(tag, **overrides):
    result = dict(tag_name=tag, body="release notes", draft=False, prerelease=False,
        assets=[dict(name=f"kaoqin-helper-{tag}.apk", size=100, state="uploaded",
            browser_download_url=f"https://github.com/Keleoz-Cyber/LessonSearch/releases/download/{tag}/app.apk")])
    result.update(overrides)
    return result


class ReleaseSelectionTest(unittest.TestCase):
    def test_uses_real_asset_and_numeric_stable_versions(self):
        info = versions.select_release([release("v0.7.1"), release("v0.10.0"),
            release("v2.0.0", prerelease=True), release("v3.0.0", draft=True), release("v4.0.0-beta")])
        self.assertEqual(info.version, "0.10.0")
        self.assertIn("github.com/", info.download_url)
        self.assertEqual(info.release_notes, "release notes")

    def test_does_not_advertise_unavailable_or_foreign_assets(self):
        missing = release("v0.8.0", assets=[])
        uploading = release("v0.9.0")
        uploading["assets"][0]["state"] = "new"
        foreign = release("v1.0.0")
        foreign["assets"][0]["browser_download_url"] = "https://example.com/fake.apk"
        info = versions.select_release([missing, uploading, foreign, release("v0.7.1")])
        self.assertEqual(info.version, "0.7.1")
        self.assertEqual(versions.select_release([]).download_url, "")


class VersionFetchTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        versions._cache.update(data=None, expires_at=0)

    def tearDown(self):
        versions._cache.update(data=None, expires_at=0)

    async def test_fetch_and_cache(self):
        response = httpx.Response(200, json=[release("v0.7.1")], request=httpx.Request("GET", versions.RELEASES_URL))
        client = AsyncMock()
        client.get.return_value = response
        with patch.object(versions.httpx, "AsyncClient") as factory:
            factory.return_value.__aenter__.return_value = client
            self.assertEqual((await versions.get_latest_version()).version, "0.7.1")
            await versions.get_latest_version()
            self.assertEqual(client.get.await_count, 1)

    async def test_network_failure_is_explicit(self):
        client = AsyncMock()
        client.get.side_effect = httpx.ConnectError("unavailable")
        with patch.object(versions.httpx, "AsyncClient") as factory:
            factory.return_value.__aenter__.return_value = client
            with self.assertRaises(HTTPException) as caught:
                await versions.get_latest_version()
        self.assertEqual(caught.exception.status_code, 503)
