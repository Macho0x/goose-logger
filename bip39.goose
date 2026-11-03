// The BIP-39 English wordlist. is_word is true for one of these words.

namespace bip39;

const ENGLISH: u8[:] = embed_file("english.txt");

fn is_word(word: u8[:]) -> bool {
    if word.len == 0 { return false; }
    let list = ENGLISH;
    var i = 0;
    while i < list.len {
        var j = i;
        while j < list.len && list[j] != '\n' && list[j] != '\r' { j += 1; }
        if j > i && list[i..j] == word { return true; }
        if j < list.len && list[j] == '\r' { j += 1; }
        if j < list.len && list[j] == '\n' { j += 1; }
        i = j;
    }
    return false;
}
