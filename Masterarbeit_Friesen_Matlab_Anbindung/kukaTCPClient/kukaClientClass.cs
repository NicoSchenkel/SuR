using System;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace kukaTCPClient
{
    public class KukaClientClass
    {
        public TcpClient clt;
        public IPAddress servAdr;
        public byte[] msgbuffer;
        public int port;
        public NetworkStream stream;
        public bool connected;

        public KukaClientClass(string ip, int port)
        {
            this.port = port;
            this.servAdr = IPAddress.Parse(ip);
            this.clt = new TcpClient();
            this.clt.ReceiveTimeout = 2000;
            this.clt.SendTimeout = 2000;
            this.msgbuffer = new byte[1024];
            this.connected = clt.Connected;
        }
        public bool ConnectToKuka()
        {
            try
            {
                clt.Connect(servAdr, port);
                stream = clt.GetStream();
                this.connected = clt.Connected;
                return true;
            }
            catch (SocketException e)
            {
                Console.WriteLine("Not possible connecting the socket, Error: {0}!", e.HResult);
                return false;
            }
            catch (ObjectDisposedException)
            {
                Console.WriteLine("Socket is disposed.");
                return false;
            }
        }

        public int SendToKuka(byte[] msg)
        {
            try
            {
                if (this.connected == false)
                {
                    this.clt = new TcpClient();
                    this.clt.ReceiveTimeout = 2000;
                    this.clt.SendTimeout = 2000;
                    this.ConnectToKuka();
                }
                stream.Write(msg, 0, msg.Length);
                this.connected = clt.Connected;
                return msg.Length;
            }
            catch (IOException e)
            {
                Console.WriteLine("Could not send msg, Error: {0}!", e.HResult);
                this.connected = clt.Connected;
                return -1;
            }
            catch (ObjectDisposedException)
            {
                Console.WriteLine("Stream is closed.");
                this.connected = clt.Connected;
                return -1;
            }
        }

        public byte[] RecvFromKuka()
        {
            try
            {
                if (this.connected == false)
                {
                    this.clt = new TcpClient();
                    this.clt.ReceiveTimeout = 2000;
                    this.clt.SendTimeout = 2000;
                    this.ConnectToKuka();
                }
                // wenn stream leer, dann hängt matlab bei read befehl
                Int32 bytes = stream.Read(msgbuffer, 0, msgbuffer.Length);          //In matlab dann mit uint8() antwort konvertieren
                this.connected = clt.Connected;                                                                    //string resp = BitConverter.ToString(msgbuffer);
                return msgbuffer;
            }
            catch (IOException e)
            {
                Console.WriteLine("Could not receive msg, Error: {0}!", e.HResult);
                byte[] empt = new byte[0];
                this.connected = clt.Connected;
                return empt;
            }
            catch (ObjectDisposedException)
            {
                Console.WriteLine("Stream is closed.");
                byte[] empt = new byte[0];
                this.connected = clt.Connected;
                return empt;
            }
            catch (ArgumentNullException)
            {
                byte[] empt = new byte[0];
                this.connected = clt.Connected;
                return empt;
            }
        }

        public bool BytesAvailable()
        {
            try
            { return stream.DataAvailable; }
            catch (IOException e)
            {
                Console.WriteLine("Could not check bytes available, Error: {0}!", e.HResult);
                this.connected = clt.Connected;
                return false;
            }
            catch (ObjectDisposedException)
            {
                Console.WriteLine("Stream is closed.");
                this.connected = clt.Connected;
                return false;
            }
        }

        public void Flush()
        {
            try
            {
                if (this.connected == false)
                {
                    this.clt = new TcpClient();
                    this.clt.ReceiveTimeout = 2000;
                    this.clt.SendTimeout = 2000;
                    this.ConnectToKuka();
                }
                while (stream.DataAvailable)
                {
                    stream.Read(msgbuffer, 0, msgbuffer.Length);
                }
                this.connected = clt.Connected;
            }
            catch (IOException e)
            {
                Console.WriteLine("Could not flush input buffer, Error: {0}!", e.HResult);
                this.connected = clt.Connected;
            }
            catch (ObjectDisposedException)
            {
                Console.WriteLine("Stream is closed.");
                this.connected = clt.Connected;
            }
        }
        public bool CloseKuka()
        {
            //Close the socket if it exists
            stream.Close();
            clt.Close();
            this.connected = clt.Connected;
            return true;
        }

    }
}
