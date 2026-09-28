package mx.ipn.escom.gestorkmp

import mx.ipn.escom.gestorkmp.data.FileEntry
import mx.ipn.escom.gestorkmp.data.FileKind
import mx.ipn.escom.gestorkmp.data.SortOption
import mx.ipn.escom.gestorkmp.data.formatSize
import mx.ipn.escom.gestorkmp.data.joinPath
import mx.ipn.escom.gestorkmp.data.parentPath
import mx.ipn.escom.gestorkmp.data.sortEntries
import kotlin.test.Test
import kotlin.test.assertEquals

/** Pruebas de la lógica compartida (se ejecutan en Android y en iOS). */
class FileEntryTest {
    private fun f(name: String, dir: Boolean = false, size: Long = 0, date: Long = 0) =
        FileEntry("/r/$name", name, dir, size, date)

    @Test
    fun kindByExtension() {
        assertEquals(FileKind.IMAGE, f("a.JPG").kind)
        assertEquals(FileKind.CODE, f("b.kt").kind)
        assertEquals(FileKind.TEXT, f("c.md").kind)
        assertEquals(FileKind.FOLDER, f("d", dir = true).kind)
    }

    @Test
    fun foldersFirstThenSort() {
        val list = listOf(f("z.txt", size = 1), f("B", dir = true), f("a.txt", size = 9))
        assertEquals(listOf("B", "a.txt", "z.txt"), list.sortEntries(SortOption.NAME, true).map { it.name })
        assertEquals(listOf("B", "a.txt", "z.txt"), list.sortEntries(SortOption.SIZE, false).map { it.name })
    }

    @Test
    fun paths() {
        assertEquals("/a/b", joinPath("/a", "b"))
        assertEquals("/a", parentPath("/a/b"))
        assertEquals("2.0 KB", formatSize(2048))
    }
}
