import { useState } from 'react';
import { Play, Pause, ThumbsUp, Plus, Music, Wifi, User, SkipForward } from 'lucide-react';

// --- Types representing our future Swift Structs ---
type Song = {
  id: string;
  title: string;
  artist: string;
  votes: number;
  addedBy: string;
  coverColor: string;
};

// --- Mock Data ---
const MOCK_LIBRARY: Song[] = [
  { id: '1', title: 'Master of Puppets', artist: 'Metallica', votes: 0, addedBy: '', coverColor: 'bg-red-800' },
  { id: '2', title: 'Midnight City', artist: 'M83', votes: 0, addedBy: '', coverColor: 'bg-purple-600' },
  { id: '3', title: 'Seasons (Waiting on You)', artist: 'Future Islands', votes: 0, addedBy: '', coverColor: 'bg-blue-500' },
  { id: '4', title: 'Under the Pressure', artist: 'The War on Drugs', votes: 0, addedBy: '', coverColor: 'bg-indigo-400' },
  { id: '5', title: 'Let It Go', artist: 'Idina Menzel', votes: 0, addedBy: '', coverColor: 'bg-cyan-400' },
];

export default function App() {
  // --- The "Server" State (Host) ---
  const [queue, setQueue] = useState<Song[]>([
    { ...MOCK_LIBRARY[1], votes: 3, addedBy: 'Eduardo' },
    { ...MOCK_LIBRARY[2], votes: 1, addedBy: 'Dad' },
  ]);
  const [nowPlaying, setNowPlaying] = useState<Song>(MOCK_LIBRARY[0]);
  const [isPlaying, setIsPlaying] = useState(false);

  // --- The "Client" State (Guest) ---
  // In a real app, this would be local to the device
  const [guestName] = useState('Santiago');

  // --- The "Democracy" Logic ---
  // Sort queue by votes (inline, not in effect)
  const sortedQueue = [...queue].sort((a, b) => b.votes - a.votes);

  const handleVote = (songId: string) => {
    setQueue(prev => prev.map(song =>
      song.id === songId ? { ...song, votes: song.votes + 1 } : song
    ));
  };

  const handleAddSong = (song: Song) => {
    // Prevent duplicates for demo
    if (queue.find(s => s.id === song.id) || nowPlaying.id === song.id) return;
    setQueue(prev => [...prev, { ...song, votes: 1, addedBy: guestName }]);
  };

  const handleSkip = () => {
    if (queue.length === 0) return;
    setNowPlaying(queue[0]);
    setQueue(prev => prev.slice(1));
  };

  return (
    <div className="flex h-screen w-full bg-gray-900 text-white overflow-hidden font-sans">

      {/* ================= LEFT: HOST (DRIVER) ================= */}
      <div className="w-1/2 border-r border-gray-700 flex flex-col relative">
        <div className="absolute top-4 left-4 bg-blue-600 text-xs px-2 py-1 rounded-full flex items-center gap-1 font-bold tracking-wide">
          <Wifi size={12} /> HOST (DRIVER)
        </div>

        {/* Now Playing Area (Big & Glanceable for Car) */}
        <div className="flex-1 flex flex-col items-center justify-center p-8 bg-gradient-to-b from-gray-800 to-gray-900">
          <div className={`w-64 h-64 ${nowPlaying.coverColor} rounded-xl shadow-2xl mb-8 flex items-center justify-center`}>
            <Music size={64} className="text-white opacity-50" />
          </div>
          <h1 className="text-3xl font-bold text-center mb-2">{nowPlaying.title}</h1>
          <p className="text-xl text-gray-400 mb-8">{nowPlaying.artist}</p>

          {/* Car Controls */}
          <div className="flex items-center gap-8">
            <button
              onClick={() => setIsPlaying(!isPlaying)}
              className="w-20 h-20 bg-white rounded-full flex items-center justify-center text-gray-900 hover:scale-105 transition-transform"
            >
              {isPlaying ? <Pause size={32} fill="currentColor" /> : <Play size={32} fill="currentColor" className="ml-1" />}
            </button>
            <button
              onClick={handleSkip}
              className="w-16 h-16 bg-gray-700 rounded-full flex items-center justify-center hover:bg-gray-600 transition-colors"
            >
              <SkipForward size={28} />
            </button>
          </div>
        </div>

        {/* Up Next Preview (Bottom Sheet) */}
        <div className="h-1/3 bg-gray-800 border-t border-gray-700 p-6 overflow-y-auto">
          <h3 className="text-xs uppercase tracking-widest text-gray-500 mb-4 font-bold">Up Next</h3>
          <div className="space-y-3">
            {sortedQueue.map((song, idx) => (
              <div key={song.id} className="flex items-center gap-4 p-3 bg-gray-700/50 rounded-lg">
                <span className="text-xl font-bold text-gray-500 w-6 text-center">{idx + 1}</span>
                <div className="flex-1">
                  <div className="font-medium">{song.title}</div>
                  <div className="text-xs text-gray-400">Votes: {song.votes} • Added by {song.addedBy}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* ================= RIGHT: GUEST (PASSENGER) ================= */}
      <div className="w-1/2 bg-black flex flex-col relative">
        <div className="absolute top-4 right-4 bg-green-600 text-xs px-2 py-1 rounded-full flex items-center gap-1 font-bold tracking-wide">
          <User size={12} /> GUEST ({guestName})
        </div>

        {/* Current Status Header */}
        <div className="p-6 border-b border-gray-800">
          <div className="text-xs text-gray-500 uppercase tracking-widest mb-1">Now Playing on Host</div>
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 ${nowPlaying.coverColor} rounded-md`} />
            <div>
              <div className="font-bold">{nowPlaying.title}</div>
              <div className="text-sm text-gray-400">{nowPlaying.artist}</div>
            </div>
          </div>
        </div>

        {/* Voting Queue */}
        <div className="flex-1 p-6 overflow-y-auto">
          <h2 className="text-xl font-bold mb-4">Vote to Play Next</h2>
          <div className="space-y-3">
            {sortedQueue.map((song) => (
              <div key={song.id} className="flex items-center justify-between p-4 bg-gray-900 border border-gray-800 rounded-xl">
                <div className="flex items-center gap-3">
                   <div className={`w-12 h-12 ${song.coverColor} rounded-md flex items-center justify-center`}>
                      <span className="text-xs font-bold">{song.votes}</span>
                   </div>
                   <div>
                     <div className="font-bold text-sm">{song.title}</div>
                     <div className="text-xs text-gray-400">{song.artist}</div>
                   </div>
                </div>
                <button
                  onClick={() => handleVote(song.id)}
                  className="p-3 bg-gray-800 rounded-full text-green-500 hover:bg-gray-700 hover:text-green-400 transition-colors active:scale-95"
                >
                  <ThumbsUp size={20} />
                </button>
              </div>
            ))}
          </div>

          <div className="mt-8 border-t border-gray-800 pt-6">
            <h2 className="text-xl font-bold mb-4">Add from Library</h2>
            <div className="space-y-2">
               {MOCK_LIBRARY.map(song => (
                 <div key={song.id} className="flex items-center justify-between p-3 hover:bg-gray-900 rounded-lg cursor-pointer group" onClick={() => handleAddSong(song)}>
                    <div className="text-sm text-gray-300">{song.title} - {song.artist}</div>
                    <Plus size={16} className="text-gray-500 group-hover:text-white" />
                 </div>
               ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
